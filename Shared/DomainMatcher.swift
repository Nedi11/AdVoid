import Foundation

/// Domain lookups against a sorted array of 64-bit FNV-1a hashes.
///
/// The packet tunnel extension has a ~50 MB memory limit, so lists are never held
/// as strings there: a 250k-domain list is ~2 MB of hashes, memory-mapped from disk.
/// A domain matches if it or any parent domain is in the list, so `ads.example.com`
/// and `x.ads.example.com` are both covered by an `ads.example.com` entry.
struct DomainMatcher {
    private let storage: Data
    let count: Int

    init(hashes: [UInt64]) {
        let sorted = hashes.sorted()
        storage = sorted.withUnsafeBufferPointer { Data(buffer: $0) }
        count = sorted.count
    }

    init(contentsOf url: URL) {
        storage = (try? Data(contentsOf: url, options: .alwaysMapped)) ?? Data()
        count = storage.count / MemoryLayout<UInt64>.size
    }

    static let empty = DomainMatcher(hashes: [])

    /// Writes hashes in the sorted on-disk format `init(contentsOf:)` reads.
    static func write<S: Sequence>(_ hashes: S, to url: URL) throws where S.Element == UInt64 {
        let sorted = Array(Set(hashes)).sorted()
        let data = sorted.withUnsafeBufferPointer { Data(buffer: $0) }
        try data.write(to: url, options: .atomic)
    }

    static func readHashes(from url: URL) -> [UInt64] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return data.withUnsafeBytes { Array($0.bindMemory(to: UInt64.self)) }
    }

    func contains(hash: UInt64) -> Bool {
        guard count > 0 else { return false }
        return storage.withUnsafeBytes { raw in
            var low = 0
            var high = count - 1
            while low <= high {
                let mid = (low + high) / 2
                let value = raw.loadUnaligned(fromByteOffset: mid * 8, as: UInt64.self)
                if value == hash { return true }
                if value < hash { low = mid + 1 } else { high = mid - 1 }
            }
            return false
        }
    }

    /// True if `domain` or any of its parent domains is in the list.
    func matches(_ domain: String) -> Bool {
        guard count > 0 else { return false }
        let bytes = Array(DomainHash.normalize(domain).utf8)
        var start = 0
        while start < bytes.count {
            if contains(hash: DomainHash.hash(bytes[start...])) { return true }
            guard let dot = bytes[start...].firstIndex(of: UInt8(ascii: ".")) else { break }
            start = dot + 1
        }
        return false
    }
}

enum DomainHash {
    static func normalize(_ domain: String) -> String {
        var d = domain.trimmingCharacters(in: .whitespaces).lowercased()
        while d.hasSuffix(".") { d.removeLast() }
        return d
    }

    static func hash(_ domain: String) -> UInt64 {
        hash(Array(normalize(domain).utf8)[...])
    }

    static func hash(_ bytes: ArraySlice<UInt8>) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in bytes {
            h ^= UInt64(byte)
            h = h &* 0x0000_0100_0000_01b3
        }
        return h
    }
}
