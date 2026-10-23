import Compression
import Foundation

/// A minimal read-only ZIP reader, enough for EPUB containers (stored and deflated entries, no ZIP64).
struct ZipArchive: Sendable {
    struct Entry: Sendable {
        let path: String
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    enum ZipError: Error {
        case invalidArchive
        case missingEntry(String)
        case unsupportedCompression(UInt16)
        case corruptEntry(String)
    }

    private let bytes: [UInt8]
    private(set) var entries: [String: Entry] = [:]

    init(data: Data) throws {
        bytes = [UInt8](data)
        entries = try Self.readCentralDirectory(bytes)
    }

    func contains(_ path: String) -> Bool {
        entry(for: path) != nil
    }

    func data(for path: String) throws -> Data {
        guard let entry = entry(for: path) else { throw ZipError.missingEntry(path) }
        let header = entry.localHeaderOffset
        guard header + 30 <= bytes.count, Self.u32(bytes, header) == 0x0403_4B50 else {
            throw ZipError.corruptEntry(path)
        }
        let start = header + 30 + Int(Self.u16(bytes, header + 26)) + Int(Self.u16(bytes, header + 28))
        let end = start + entry.compressedSize
        guard end <= bytes.count else { throw ZipError.corruptEntry(path) }

        switch entry.method {
        case 0:
            return Data(bytes[start..<end])
        case 8:
            return try inflate(start..<end, expectedSize: entry.uncompressedSize, path: path)
        default:
            throw ZipError.unsupportedCompression(entry.method)
        }
    }

    private func entry(for path: String) -> Entry? {
        if let entry = entries[path] { return entry }
        let lowered = path.lowercased()
        return entries.first { $0.key.lowercased() == lowered }?.value
    }

    private func inflate(_ range: Range<Int>, expectedSize: Int, path: String) throws -> Data {
        guard expectedSize > 0 else { return Data() }
        var output = Data(count: expectedSize)
        let written = output.withUnsafeMutableBytes { destination in
            bytes.withUnsafeBufferPointer { source in
                compression_decode_buffer(
                    destination.bindMemory(to: UInt8.self).baseAddress!,
                    expectedSize,
                    source.baseAddress! + range.lowerBound,
                    range.count,
                    nil,
                    COMPRESSION_ZLIB // raw DEFLATE, which is what ZIP stores
                )
            }
        }
        guard written == expectedSize else { throw ZipError.corruptEntry(path) }
        return output
    }

    private static func readCentralDirectory(_ bytes: [UInt8]) throws -> [String: Entry] {
        let eocdSize = 22
        guard bytes.count >= eocdSize else { throw ZipError.invalidArchive }

        var eocd = -1
        var cursor = bytes.count - eocdSize
        let floor = max(0, bytes.count - eocdSize - 65_535)
        while cursor >= floor {
            if u32(bytes, cursor) == 0x0605_4B50 { eocd = cursor; break }
            cursor -= 1
        }
        guard eocd >= 0 else { throw ZipError.invalidArchive }

        let count = Int(u16(bytes, eocd + 10))
        var offset = Int(u32(bytes, eocd + 16))
        var entries: [String: Entry] = [:]
        entries.reserveCapacity(count)

        for _ in 0..<count {
            guard offset + 46 <= bytes.count, u32(bytes, offset) == 0x0201_4B50 else {
                throw ZipError.invalidArchive
            }
            let method = u16(bytes, offset + 10)
            let compressedSize = Int(u32(bytes, offset + 20))
            let uncompressedSize = Int(u32(bytes, offset + 24))
            let nameLength = Int(u16(bytes, offset + 28))
            let extraLength = Int(u16(bytes, offset + 30))
            let commentLength = Int(u16(bytes, offset + 32))
            let localHeader = Int(u32(bytes, offset + 42))
            guard offset + 46 + nameLength <= bytes.count else { throw ZipError.invalidArchive }

            let nameBytes = bytes[(offset + 46)..<(offset + 46 + nameLength)]
            let name = String(bytes: nameBytes, encoding: .utf8)
                ?? String(bytes: nameBytes, encoding: .isoLatin1)
                ?? ""
            if !name.hasSuffix("/") {
                entries[name] = Entry(
                    path: name,
                    method: method,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize,
                    localHeaderOffset: localHeader
                )
            }
            offset += 46 + nameLength + extraLength + commentLength
        }
        return entries
    }

    private static func u16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private static func u32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }
}
