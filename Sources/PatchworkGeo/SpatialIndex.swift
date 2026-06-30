import Foundation

/// A static, bulk-loaded R-tree over feature bounding boxes.
///
/// This is the broad phase that makes coordinate→ZCTA lookup sublinear instead of a scan of
/// every polygon (locked V1 decision #7). It is built once at load time via Sort-Tile-
/// Recursive (STR) packing — items sorted into vertical slices, then tiled into leaves — and
/// queried with an iterative bbox-intersection descent. The node layout is flattened into
/// parallel arrays so the hot query path touches no reference types.
public struct SpatialIndex: Sendable {
    /// Node bounding boxes, parallel arrays indexed by node id.
    private let nodeMinX: [Double]
    private let nodeMinY: [Double]
    private let nodeMaxX: [Double]
    private let nodeMaxY: [Double]
    /// For each node: where its children/items begin and how many there are.
    private let childStart: [Int]
    private let childCount: [Int]
    private let nodeIsLeaf: [Bool]
    /// Internal-node children (node ids) and leaf items (original feature indices).
    private let childNodes: [Int]
    private let leafItems: [Int]
    /// Original per-item bounding boxes, indexed by item id, for the exact leaf-level test.
    private let itemBoxes: [BoundingBox]
    private let rootID: Int

    public let itemCount: Int
    public let nodeSize: Int

    /// Builds the index from one bounding box per item. Item ids are the array positions.
    public init(boxes: [BoundingBox], nodeSize: Int = 16) {
        precondition(nodeSize >= 2, "nodeSize must be >= 2")
        self.nodeSize = nodeSize
        self.itemCount = boxes.count
        self.itemBoxes = boxes

        var minX: [Double] = []
        var minY: [Double] = []
        var maxX: [Double] = []
        var maxY: [Double] = []
        var cStart: [Int] = []
        var cCount: [Int] = []
        var isLeaf: [Bool] = []
        var childNodesAcc: [Int] = []
        var leafItemsAcc: [Int] = []

        func addNode(box: BoundingBox, leaf: Bool, start: Int, count: Int) -> Int {
            minX.append(box.minX); minY.append(box.minY)
            maxX.append(box.maxX); maxY.append(box.maxY)
            cStart.append(start); cCount.append(count)
            isLeaf.append(leaf)
            return minX.count - 1
        }

        if boxes.isEmpty {
            self.rootID = addNode(box: BoundingBox(minX: 0, minY: 0, maxX: 0, maxY: 0),
                                  leaf: true, start: 0, count: 0)
            self.nodeMinX = minX; self.nodeMinY = minY
            self.nodeMaxX = maxX; self.nodeMaxY = maxY
            self.childStart = cStart; self.childCount = cCount
            self.nodeIsLeaf = isLeaf
            self.childNodes = childNodesAcc; self.leafItems = leafItemsAcc
            return
        }

        // Build leaf level: STR-group item ids, each group becomes a leaf node.
        let itemIDs = Array(0..<boxes.count)
        let leafGroups = SpatialIndex.strGroups(ids: itemIDs, nodeSize: nodeSize) { boxes[$0] }
        var currentLevel: [Int] = [] // node ids forming the current (lowest) level
        for group in leafGroups {
            var box = boxes[group[0]]
            for id in group.dropFirst() { box.expand(toInclude: boxes[id]) }
            let start = leafItemsAcc.count
            leafItemsAcc.append(contentsOf: group)
            let nodeID = addNode(box: box, leaf: true, start: start, count: group.count)
            currentLevel.append(nodeID)
        }

        // Build internal levels bottom-up until a single root remains.
        while currentLevel.count > 1 {
            let groups = SpatialIndex.strGroups(ids: currentLevel, nodeSize: nodeSize) { nodeID in
                BoundingBox(minX: minX[nodeID], minY: minY[nodeID],
                            maxX: maxX[nodeID], maxY: maxY[nodeID])
            }
            var nextLevel: [Int] = []
            for group in groups {
                var box = BoundingBox(minX: minX[group[0]], minY: minY[group[0]],
                                      maxX: maxX[group[0]], maxY: maxY[group[0]])
                for nodeID in group.dropFirst() {
                    box.expand(toInclude: BoundingBox(minX: minX[nodeID], minY: minY[nodeID],
                                                      maxX: maxX[nodeID], maxY: maxY[nodeID]))
                }
                let start = childNodesAcc.count
                childNodesAcc.append(contentsOf: group)
                let nodeID = addNode(box: box, leaf: false, start: start, count: group.count)
                nextLevel.append(nodeID)
            }
            currentLevel = nextLevel
        }

        self.rootID = currentLevel.first ?? 0
        self.nodeMinX = minX; self.nodeMinY = minY
        self.nodeMaxX = maxX; self.nodeMaxY = maxY
        self.childStart = cStart; self.childCount = cCount
        self.nodeIsLeaf = isLeaf
        self.childNodes = childNodesAcc; self.leafItems = leafItemsAcc
    }

    /// Returns item ids whose bounding box intersects `box`. Order is unspecified.
    public func query(_ box: BoundingBox) -> [Int] {
        var results: [Int] = []
        guard itemCount > 0 else { return results }
        var stack: [Int] = [rootID]
        while let nodeID = stack.popLast() {
            // Prune: skip nodes whose box doesn't intersect the query.
            if nodeMinX[nodeID] > box.maxX || nodeMaxX[nodeID] < box.minX ||
               nodeMinY[nodeID] > box.maxY || nodeMaxY[nodeID] < box.minY {
                continue
            }
            let start = childStart[nodeID]
            let count = childCount[nodeID]
            if nodeIsLeaf[nodeID] {
                for k in start..<(start + count) {
                    let item = leafItems[k]
                    // Exact leaf test: keep only items whose own box meets the query.
                    if itemBoxes[item].intersects(box) { results.append(item) }
                }
            } else {
                for k in start..<(start + count) {
                    stack.append(childNodes[k])
                }
            }
        }
        return results
    }

    /// Convenience: all item ids whose box contains `p`.
    public func query(point p: Point2D) -> [Int] {
        query(BoundingBox(point: p))
    }

    // MARK: - STR packing

    /// Groups `ids` into tiles of at most `nodeSize` using Sort-Tile-Recursive ordering:
    /// sort by box center-x into ⌈√P⌉ vertical slices, then sort each slice by center-y and
    /// chop into runs of `nodeSize`. Produces spatially compact leaves/nodes.
    static func strGroups(ids: [Int], nodeSize: Int, box: (Int) -> BoundingBox) -> [[Int]] {
        let count = ids.count
        if count <= nodeSize { return [ids] }
        let leafCount = Int((Double(count) / Double(nodeSize)).rounded(.up))
        let sliceCount = max(1, Int(Double(leafCount).squareRoot().rounded(.up)))
        let perSlice = Int((Double(count) / Double(sliceCount)).rounded(.up))

        let sortedByX = ids.sorted { box($0).centerX < box($1).centerX }
        var groups: [[Int]] = []
        var i = 0
        while i < count {
            let sliceEnd = min(i + perSlice, count)
            let slice = sortedByX[i..<sliceEnd].sorted { box($0).centerY < box($1).centerY }
            var j = 0
            while j < slice.count {
                let runEnd = min(j + nodeSize, slice.count)
                groups.append(Array(slice[j..<runEnd]))
                j = runEnd
            }
            i = sliceEnd
        }
        return groups
    }
}
