//
//  RemoteFrameCodec.swift
//  RCProxyCore
//
//  Splits messages into small frames (and puts them back together), so that large
//  response bodies never have to travel as a single huge MultipeerConnectivity packet.
//

import Foundation

/// Frame layout (big endian):
///
///     0..<4    magic "RCPX"
///     4        protocol version
///     5        flags (bit 0: payload is zlib-compressed)
///     6..<22   message identifier (UUID)
///     22..<26  chunk index
///     26..<30  chunk count
///     30...    chunk bytes
enum RemoteFrameCodec {

    static let magic: [UInt8] = [0x52, 0x43, 0x50, 0x58] // "RCPX"
    static let headerSize = 30
    static let defaultChunkSize = 32 * 1024
    /// Messages bigger than this are refused by the receiver (protects against corrupted headers).
    static let maxChunkCount: UInt32 = 65_536
    private static let compressedFlag: UInt8 = 1

    // MARK: Encoding

    static func encode(_ message: RemoteMessage, chunkSize: Int = defaultChunkSize) throws -> [Data] {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        var payload = try encoder.encode(message)
        var flags: UInt8 = 0

        if payload.count > 1024,
           let compressed = try? (payload as NSData).compressed(using: .zlib) as Data,
           compressed.count < payload.count {
            payload = compressed
            flags |= compressedFlag
        }

        let chunkSize = max(1, chunkSize)
        let chunkCount = max(1, (payload.count + chunkSize - 1) / chunkSize)
        let identifier = UUID()
        var frames: [Data] = []
        frames.reserveCapacity(chunkCount)

        for index in 0..<chunkCount {
            let start = payload.startIndex + index * chunkSize
            let end = min(start + chunkSize, payload.endIndex)
            var frame = Data(capacity: headerSize + (end - start))
            frame.append(contentsOf: magic)
            frame.append(UInt8(RemoteLink.protocolVersion))
            frame.append(flags)
            withUnsafeBytes(of: identifier.uuid) { frame.append(contentsOf: $0) }
            frame.append(contentsOf: bigEndianBytes(UInt32(index)))
            frame.append(contentsOf: bigEndianBytes(UInt32(chunkCount)))
            if start < end {
                frame.append(payload[start..<end])
            }
            frames.append(frame)
        }
        return frames
    }

    // MARK: Decoding

    struct Header {
        let flags: UInt8
        let identifier: UUID
        let index: UInt32
        let count: UInt32
    }

    static func header(of frame: Data) -> Header? {
        guard frame.count >= headerSize else { return nil }
        let bytes = [UInt8](frame.prefix(headerSize))
        guard Array(bytes[0..<4]) == magic, bytes[4] == UInt8(RemoteLink.protocolVersion) else { return nil }
        let uuidBytes = Array(bytes[6..<22])
        let identifier = UUID(uuid: (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ))
        let index = uint32(bytes[22..<26])
        let count = uint32(bytes[26..<30])
        guard count >= 1, count <= maxChunkCount, index < count else { return nil }
        return Header(flags: bytes[5], identifier: identifier, index: index, count: count)
    }

    static func decode(payload: Data, flags: UInt8) -> RemoteMessage? {
        var payload = payload
        if flags & compressedFlag != 0 {
            guard let inflated = try? (payload as NSData).decompressed(using: .zlib) as Data else { return nil }
            payload = inflated
        }
        return try? PropertyListDecoder().decode(RemoteMessage.self, from: payload)
    }

    private static func bigEndianBytes(_ value: UInt32) -> [UInt8] {
        [UInt8(truncatingIfNeeded: value >> 24),
         UInt8(truncatingIfNeeded: value >> 16),
         UInt8(truncatingIfNeeded: value >> 8),
         UInt8(truncatingIfNeeded: value)]
    }

    private static func uint32(_ bytes: ArraySlice<UInt8>) -> UInt32 {
        bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }
}

/// Puts the frames of one sender back together. Not thread-safe: use one assembler per connection,
/// from a single queue.
struct RemoteFrameAssembler {

    private struct Partial {
        let flags: UInt8
        let count: Int
        var chunks: [Int: Data] = [:]
    }

    private var partials: [UUID: Partial] = [:]
    private var order: [UUID] = []
    /// Maximum number of messages that can be incomplete at the same time.
    private let maxPendingMessages = 8

    init() {}

    /// Feeds a frame. Returns a message when the frame completes one.
    /// Malformed frames are ignored.
    mutating func ingest(_ frame: Data) -> RemoteMessage? {
        guard let header = RemoteFrameCodec.header(of: frame) else { return nil }
        let chunk = frame.dropFirst(RemoteFrameCodec.headerSize)

        if header.count == 1 {
            return RemoteFrameCodec.decode(payload: Data(chunk), flags: header.flags)
        }

        var partial = partials[header.identifier] ?? Partial(flags: header.flags, count: Int(header.count))
        guard partial.count == Int(header.count) else {
            discard(header.identifier)
            return nil
        }
        if partials[header.identifier] == nil {
            order.append(header.identifier)
            if order.count > maxPendingMessages {
                partials[order.removeFirst()] = nil
            }
        }
        partial.chunks[Int(header.index)] = Data(chunk)

        guard partial.chunks.count == partial.count else {
            partials[header.identifier] = partial
            return nil
        }

        discard(header.identifier)
        var payload = Data()
        for index in 0..<partial.count {
            guard let part = partial.chunks[index] else { return nil }
            payload.append(part)
        }
        return RemoteFrameCodec.decode(payload: payload, flags: partial.flags)
    }

    private mutating func discard(_ identifier: UUID) {
        partials[identifier] = nil
        order.removeAll { $0 == identifier }
    }
}
