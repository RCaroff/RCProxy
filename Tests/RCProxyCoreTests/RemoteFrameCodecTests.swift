import XCTest
@testable import RCProxyCore

final class RemoteFrameCodecTests: XCTestCase {

    private func makeItem(id: String = "1", bodySize: Int = 0) -> RequestItem {
        var generator = SystemRandomNumberGenerator()
        // Random bytes do not compress: the message really needs several frames.
        let body = Data((0..<bodySize).map { _ in UInt8.random(in: 0...255, using: &generator) })
        return RequestItem(
            id: id,
            fullURL: "https://example.com/\(id)",
            method: "GET",
            responseBodyData: bodySize == 0 ? nil : body,
            statusCode: 200
        )
    }

    private func assemble(_ frames: [Data]) -> [RemoteMessage] {
        var assembler = RemoteFrameAssembler()
        return frames.compactMap { assembler.ingest($0) }
    }

    func testSmallMessageFitsInOneFrame() throws {
        let frames = try RemoteFrameCodec.encode(.upsert(makeItem(id: "small")))
        XCTAssertEqual(frames.count, 1)

        let messages = assemble(frames)
        guard case .upsert(let item)? = messages.first, messages.count == 1 else {
            return XCTFail("Expected one upsert, got \(messages)")
        }
        XCTAssertEqual(item.id, "small")
    }

    func testHelloRoundTrip() throws {
        let device = RemoteDeviceInfo(
            id: "device", name: "Salon", model: "Apple TV", systemName: "tvOS", systemVersion: "18.0",
            appName: "Demo", appIdentifier: "com.example.demo", appVersion: "1.0 (1)",
            libraryVersion: "4.0.0", isSimulator: true
        )
        let messages = assemble(try RemoteFrameCodec.encode(.hello(device)))

        guard case .hello(let decoded)? = messages.first else { return XCTFail("Expected hello") }
        XCTAssertEqual(decoded, device)
    }

    func testLargeMessageIsSplitAndReassembled() throws {
        let original = makeItem(id: "large", bodySize: 300_000)
        let frames = try RemoteFrameCodec.encode(.upsert(original), chunkSize: 16 * 1024)
        XCTAssertGreaterThan(frames.count, 10)
        XCTAssertTrue(frames.allSatisfy { $0.count <= 16 * 1024 + RemoteFrameCodec.headerSize })

        let messages = assemble(frames)
        guard case .upsert(let item)? = messages.first, messages.count == 1 else {
            return XCTFail("Expected one upsert")
        }
        XCTAssertEqual(item.responseBodyData, original.responseBodyData)
    }

    func testCompressibleBodyUsesFewerFrames() throws {
        var item = makeItem(id: "json")
        item.responseBodyData = Data(String(repeating: #"{"name":"value","count":42},"#, count: 20_000).utf8)

        let frames = try RemoteFrameCodec.encode(.upsert(item), chunkSize: 16 * 1024)
        XCTAssertLessThan(frames.count, 5, "A repetitive 500 kB body should compress to a few frames")

        guard case .upsert(let decoded)? = assemble(frames).first else { return XCTFail("Expected upsert") }
        XCTAssertEqual(decoded.responseBodyData, item.responseBodyData)
    }

    func testFramesMayArriveOutOfOrderAndInterleaved() throws {
        let first = makeItem(id: "first", bodySize: 50_000)
        let second = makeItem(id: "second", bodySize: 50_000)
        let framesA = try RemoteFrameCodec.encode(.upsert(first), chunkSize: 8 * 1024)
        let framesB = try RemoteFrameCodec.encode(.upsert(second), chunkSize: 8 * 1024)

        var mixed: [Data] = []
        for index in 0..<max(framesA.count, framesB.count) {
            if index < framesB.count { mixed.append(framesB.reversed()[index]) }
            if index < framesA.count { mixed.append(framesA[index]) }
        }

        let ids = assemble(mixed).compactMap { message -> String? in
            if case .upsert(let item) = message { return item.id }
            return nil
        }
        XCTAssertEqual(Set(ids), ["first", "second"])
    }

    func testMalformedFramesAreIgnored() throws {
        let valid = try RemoteFrameCodec.encode(.upsert(makeItem(id: "valid", bodySize: 40_000)), chunkSize: 8 * 1024)
        var assembler = RemoteFrameAssembler()

        // Garbage of every size, including sizes around the header size.
        for size in [0, 1, 4, 29, 30, 31, 64, 5_000] {
            XCTAssertNil(assembler.ingest(Data(repeating: 0xAB, count: size)))
        }

        // Valid magic, inconsistent counters.
        var badCount = valid[0]
        badCount.replaceSubrange(26..<30, with: [0, 0, 0, 0])
        XCTAssertNil(assembler.ingest(badCount))

        var badIndex = valid[0]
        badIndex.replaceSubrange(22..<26, with: [0xFF, 0xFF, 0xFF, 0xFF])
        XCTAssertNil(assembler.ingest(badIndex))

        var hugeCount = valid[0]
        hugeCount.replaceSubrange(26..<30, with: [0xFF, 0xFF, 0xFF, 0xFF])
        XCTAssertNil(assembler.ingest(hugeCount))

        // A single-frame message whose payload is not a message.
        var notAMessage = try RemoteFrameCodec.encode(.upsert(makeItem(id: "x")))[0]
        notAMessage.replaceSubrange(RemoteFrameCodec.headerSize..<notAMessage.count, with: [1, 2, 3])
        XCTAssertNil(assembler.ingest(notAMessage))

        // The assembler still works afterwards.
        let messages = valid.compactMap { assembler.ingest($0) }
        XCTAssertEqual(messages.count, 1)
    }

    func testTruncatedFrameDoesNotProduceAMessage() throws {
        var frames = try RemoteFrameCodec.encode(.upsert(makeItem(id: "cut", bodySize: 40_000)), chunkSize: 8 * 1024)
        frames[2] = frames[2].prefix(RemoteFrameCodec.headerSize + 10)

        XCTAssertTrue(assemble(frames).isEmpty)
    }

    func testFramesWorkWhenDataIsASlice() throws {
        let frame = try RemoteFrameCodec.encode(.upsert(makeItem(id: "slice")))[0]
        let padded = Data([9, 9, 9]) + frame
        // A slice does not start at index 0: indexing must not assume it does.
        let slice = padded[3...]

        guard case .upsert(let item)? = assemble([slice]).first else { return XCTFail("Expected upsert") }
        XCTAssertEqual(item.id, "slice")
    }

    func testPeerDisplayNameIsAlwaysValid() {
        XCTAssertEqual(RemoteLink.peerDisplayName(""), "RCProxy")
        XCTAssertEqual(RemoteLink.peerDisplayName("   \n"), "RCProxy")
        XCTAssertEqual(RemoteLink.peerDisplayName("Apple TV"), "Apple TV")

        let long = String(repeating: "é📺", count: 40)
        let name = RemoteLink.peerDisplayName(long)
        XCTAssertLessThanOrEqual(name.utf8.count, 63)
        XCTAssertFalse(name.isEmpty)
        XCTAssertTrue(long.hasPrefix(name), "Truncation must not cut a character in half")
    }
}
