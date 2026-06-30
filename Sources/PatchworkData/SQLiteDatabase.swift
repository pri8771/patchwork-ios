import Foundation
import SQLite3

/// A minimal read-only wrapper over the system SQLite3 library.
///
/// Honors the "no third-party dependencies" rule (locked exclusions): we link the OS-provided
/// `sqlite3` rather than pulling in a Swift SQLite package. The bundled geodata is read-only,
/// so this exposes just enough to prepare statements and read rows.
final class SQLiteDatabase {
    enum DBError: Error, CustomStringConvertible {
        case openFailed(String)
        case prepareFailed(String)
        case missingFile(String)

        var description: String {
            switch self {
            case .openFailed(let m): return "SQLite open failed: \(m)"
            case .prepareFailed(let m): return "SQLite prepare failed: \(m)"
            case .missingFile(let p): return "Database file not found: \(p)"
            }
        }
    }

    // SQLite wants this sentinel for transient text/blob bindings.
    private static let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private var handle: OpaquePointer?

    init(path: String, readonly: Bool = true) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw DBError.missingFile(path)
        }
        let flags = readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        if sqlite3_open_v2(path, &handle, flags, nil) != SQLITE_OK {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw DBError.openFailed(msg)
        }
    }

    deinit { sqlite3_close(handle) }

    /// Prepares and iterates a query, invoking `row` for each result row.
    func query(_ sql: String, bind: [Binding] = [], row: (Row) -> Void) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(handle))
            throw DBError.prepareFailed("\(msg) — \(sql)")
        }
        defer { sqlite3_finalize(stmt) }
        for (i, binding) in bind.enumerated() {
            let col = Int32(i + 1)
            switch binding {
            case .int(let v): sqlite3_bind_int64(stmt, col, Int64(v))
            case .double(let v): sqlite3_bind_double(stmt, col, v)
            case .text(let v): sqlite3_bind_text(stmt, col, v, -1, Self.SQLITE_TRANSIENT)
            }
        }
        while sqlite3_step(stmt) == SQLITE_ROW {
            row(Row(stmt: stmt!))
        }
    }

    enum Binding {
        case int(Int)
        case double(Double)
        case text(String)
    }

    /// A single result row; columns are read positionally.
    struct Row {
        let stmt: OpaquePointer

        func int(_ index: Int32) -> Int { Int(sqlite3_column_int64(stmt, index)) }
        func double(_ index: Int32) -> Double { sqlite3_column_double(stmt, index) }

        func text(_ index: Int32) -> String? {
            guard let c = sqlite3_column_text(stmt, index) else { return nil }
            return String(cString: c)
        }

        func blob(_ index: Int32) -> [UInt8] {
            guard let bytes = sqlite3_column_blob(stmt, index) else { return [] }
            let count = Int(sqlite3_column_bytes(stmt, index))
            return [UInt8](UnsafeBufferPointer(
                start: bytes.assumingMemoryBound(to: UInt8.self), count: count))
        }
    }
}
