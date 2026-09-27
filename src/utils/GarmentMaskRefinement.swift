import CoreGraphics
import Foundation

/// Geometry for automatic SAM prompts and for removing isolated mask fragments.
enum GarmentMaskRefinement {
    /// Coordinates use the top-left image origin expected by SAM.
    static func promptPoints(mask: [UInt8], width: Int, height: Int) -> [CGPoint] {
        guard width > 2, height > 2, mask.count == width * height else { return [] }
        let foreground = mask.map { $0 >= 128 }
        let regions = components(foreground, width: width, height: height)
        guard let main = regions.max(by: { $0.count < $1.count }), main.count > 4 else { return [] }
        var inside = [Bool](repeating: false, count: mask.count)
        for index in main { inside[index] = true }
        let minX = main.map { $0 % width }.min()!
        let maxX = main.map { $0 % width }.max()!
        let minY = main.map { $0 / width }.min()!
        let maxY = main.map { $0 / width }.max()!
        // Interior distance prevents a foreground prompt from landing on a weak edge.
        var distance = inside.map { $0 ? width + height : 0 }
        for y in 0..<height {
            for x in 0..<width where inside[y * width + x] {
                let index = y * width + x
                distance[index] = min(distance[index], x == 0 ? 1 : distance[index - 1] + 1)
                distance[index] = min(distance[index], y == 0 ? 1 : distance[index - width] + 1)
            }
        }
        for y in (0..<height).reversed() {
            for x in (0..<width).reversed() where inside[y * width + x] {
                let index = y * width + x
                distance[index] = min(distance[index], x == width - 1 ? 1 : distance[index + 1] + 1)
                distance[index] = min(distance[index], y == height - 1 ? 1 : distance[index + width] + 1)
            }
        }
        let targets: [(Double, Double)] = [(0.35, 0.5), (0.65, 0.5), (0.5, 0.75)]
        let margin = max(2, (distance.max() ?? 1) / 4)
        let interior = main.filter { distance[$0] >= margin }
        let candidates = interior.isEmpty ? main : interior
        var selected = [Int]()
        for (tx, ty) in targets {
            let x = Double(minX) + tx * Double(maxX - minX)
            let y = Double(minY) + ty * Double(maxY - minY)
            let remaining = candidates.filter { !selected.contains($0) }
            if let nearest = remaining.min(by: {
                squaredDistance($0, x: x, y: y, width: width)
                    < squaredDistance($1, x: x, y: y, width: width)
            }) { selected.append(nearest) }
        }
        var points = selected.map {
            CGPoint(x: (Double($0 % width) + 0.5) / Double(width),
                    y: (Double($0 / width) + 0.5) / Double(height))
        }
        // A comparable neighboring piece may be the other shoe. Prompt it explicitly.
        let mainCenter = center(of: main, width: width, height: height)
        if let pair = regions.filter({ region in
            guard region.first != main.first, region.count >= main.count / 2 else { return false }
            let candidateCenter = center(of: region, width: width, height: height)
            return abs(candidateCenter.y - mainCenter.y) < 0.35
                && abs(candidateCenter.x - mainCenter.x) < 0.65
        }).max(by: { $0.count < $1.count }) {
            let pairCenter = center(of: pair, width: width, height: height)
            if let index = pair.min(by: {
                squaredDistance($0, x: pairCenter.x * Double(width), y: pairCenter.y * Double(height), width: width)
                    < squaredDistance($1, x: pairCenter.x * Double(width), y: pairCenter.y * Double(height), width: width)
            }) {
                points.append(CGPoint(x: (Double(index % width) + 0.5) / Double(width),
                                      y: (Double(index / width) + 0.5) / Double(height)))
            }
        }
        return points
    }

    static func cleanedLogits(_ logits: [Float], width: Int, height: Int) -> [Float]? {
        guard width > 0, height > 0, logits.count == width * height,
              logits.allSatisfy(\.isFinite) else { return nil }
        let regions = components(logits.map { $0 > 0 }, width: width, height: height)
        guard let largest = regions.map(\.count).max(), largest >= 4 else { return nil }
        // Keep substantial paired pieces (e.g. shoes), while dropping dust and isolated scraps.
        let retained = regions.filter { $0.count >= max(4, largest / 3) }
        var keep = [Bool](repeating: false, count: logits.count)
        for region in retained { for index in region { keep[index] = true } }
        var result = logits
        for index in result.indices where !keep[index] {
            let x = index % width, y = index / width
            let bordersGarment = (-1...1).contains { dy in
                (-1...1).contains { dx in
                    let nx = x + dx, ny = y + dy
                    return nx >= 0 && nx < width && ny >= 0 && ny < height && keep[ny * width + nx]
                }
            }
            // Weak, negative logits far from the garment can otherwise become translucent scraps.
            if !bordersGarment || logits[index] > 0 { result[index] = -16 }
        }
        // Fill only small enclosed pinholes; sleeve openings and other large gaps stay transparent.
        let holes = components(keep.map { !$0 }, width: width, height: height)
        for hole in holes where hole.count <= max(4, largest / 1_000) {
            let touchesEdge = hole.contains {
                $0 % width == 0 || $0 % width == width - 1 || $0 / width == 0 || $0 / width == height - 1
            }
            if !touchesEdge { for index in hole { result[index] = 8 } }
        }
        return result
    }

    private static func center(of region: [Int], width: Int, height: Int) -> CGPoint {
        CGPoint(x: Double(region.reduce(0) { $0 + $1 % width }) / Double(region.count * width),
                y: Double(region.reduce(0) { $0 + $1 / width }) / Double(region.count * height))
    }

    private static func squaredDistance(_ index: Int, x: Double, y: Double, width: Int) -> Double {
        let dx = Double(index % width) - x
        let dy = Double(index / width) - y
        return dx * dx + dy * dy
    }

    private static func components(_ foreground: [Bool], width: Int, height: Int) -> [[Int]] {
        var visited = [Bool](repeating: false, count: foreground.count)
        var regions = [[Int]]()
        for start in foreground.indices where foreground[start] && !visited[start] {
            var region = [start]
            visited[start] = true
            var cursor = 0
            while cursor < region.count {
                let index = region[cursor]
                cursor += 1
                let x = index % width, y = index / width
                let neighbors = [x > 0 ? index - 1 : -1, x + 1 < width ? index + 1 : -1,
                                 y > 0 ? index - width : -1, y + 1 < height ? index + width : -1]
                for next in neighbors where next >= 0 && foreground[next] && !visited[next] {
                    visited[next] = true
                    region.append(next)
                }
            }
            regions.append(region)
        }
        return regions
    }
}
