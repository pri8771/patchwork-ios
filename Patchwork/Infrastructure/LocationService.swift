import Foundation
import CoreLocation
import Combine

/// Wraps CoreLocation with a While-Using-first posture (locked decision #10).
///
/// Patchwork only ever asks for location in response to the user's "Claim Current Patch" tap;
/// it requests When-In-Use authorization and takes a single fix. There is no background or
/// Always usage in V1 — that's reserved behind a later, explicit in-app permission gate. Nothing
/// here uploads anything; the coordinate is resolved to a ZCTA entirely on device.
@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isResolving = false

    private let manager = CLLocationManager()
    private var fixContinuations: [CheckedContinuation<CLLocation, Error>] = []
    private var authContinuations: [CheckedContinuation<CLAuthorizationStatus, Never>] = []

    enum LocationError: LocalizedError {
        case denied
        case restricted
        case unavailable
        case timeout

        var errorDescription: String? {
            switch self {
            case .denied: return "Location access is off. Turn it on in Settings to claim where you are."
            case .restricted: return "Location access is restricted on this device."
            case .unavailable: return "Couldn’t get a location fix. Try again in a moment."
            case .timeout: return "Finding your location took too long. Try again."
            }
        }
    }

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// Requests When-In-Use authorization and resolves once the user responds.
    func requestWhenInUseAuthorization() async -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            authContinuations.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
    }

    /// Takes a single location fix. Requests authorization first if needed.
    func requestCurrentLocation() async throws -> CLLocation {
        if manager.authorizationStatus == .notDetermined {
            _ = await requestWhenInUseAuthorization()
        }
        switch manager.authorizationStatus {
        case .denied: throw LocationError.denied
        case .restricted: throw LocationError.restricted
        default: break
        }

        isResolving = true
        defer { isResolving = false }

        return try await withThrowingTaskGroup(of: CLLocation.self) { group in
            group.addTask { @MainActor in
                try await withCheckedThrowingContinuation { continuation in
                    self.fixContinuations.append(continuation)
                    self.manager.requestLocation()
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 12 * 1_000_000_000)
                throw LocationError.timeout
            }
            guard let result = try await group.next() else { throw LocationError.unavailable }
            group.cancelAll()
            return result
        }
    }

    private func resumeFixes(with result: Result<CLLocation, Error>) {
        let conts = fixContinuations
        fixContinuations.removeAll()
        for c in conts { c.resume(with: result) }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            let conts = self.authContinuations
            self.authContinuations.removeAll()
            for c in conts { c.resume(returning: manager.authorizationStatus) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.resumeFixes(with: .success(location)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.resumeFixes(with: .failure(LocationService.LocationError.unavailable)) }
    }
}
