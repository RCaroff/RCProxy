import XCTest
import RCProxyCore
@testable import RCProxy

final class ExecutionGateTests: XCTestCase {

    /// Collects what the completions of the held requests receive.
    private final class Outcomes: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String: RemoteExecutionResult?] = [:]

        func completion(for id: String) -> ExecutionGate.Completion {
            { [self] result in
                lock.lock()
                values[id] = result
                lock.unlock()
            }
        }

        var completedIDs: [String] {
            lock.lock()
            defer { lock.unlock() }
            return values.keys.sorted()
        }
    }

    private let start = Date(timeIntervalSinceReferenceDate: 1_000)
    private let outcomes = Outcomes()

    private func request(_ id: String) -> RemoteExecutionRequest {
        RemoteExecutionRequest(id: id, url: "https://gate.example.com/\(id)", method: "GET")
    }

    private func hold(_ id: String, in gate: inout ExecutionGate, at seconds: TimeInterval) -> Bool {
        gate.hold(request(id), completion: outcomes.completion(for: id), now: start.addingTimeInterval(seconds))
    }

    func testNothingWaitsWhenNobodyIsExpected() {
        var gate = ExecutionGate()
        XCTAssertFalse(hold("a", in: &gate, at: 0))
        XCTAssertTrue(gate.pending.isEmpty)
        XCTAssertNil(gate.expire(now: start.addingTimeInterval(60)), "No wait: nothing ends")
    }

    func testRequestsWaitForTheExpectedMac() {
        var gate = ExecutionGate()
        gate.expectExecutor(until: start.addingTimeInterval(5))

        XCTAssertTrue(hold("a", in: &gate, at: 0))
        XCTAssertTrue(hold("b", in: &gate, at: 4.9))
        XCTAssertNil(gate.expire(now: start.addingTimeInterval(3)), "Too early")

        // The Mac arrives: it gets the requests, in order, and the next ones do not wait.
        let waiting = gate.executorArrived()
        XCTAssertEqual(waiting.map(\.request.id), ["a", "b"])
        XCTAssertTrue(gate.pending.isEmpty)
        XCTAssertFalse(hold("c", in: &gate, at: 1))
        XCTAssertNil(gate.expire(now: start.addingTimeInterval(10)), "The Mac is there: nothing to give back")
        XCTAssertTrue(gate.executorArrived().isEmpty, "Reported again: nothing left to send")
        XCTAssertTrue(outcomes.completedIDs.isEmpty, "The gate never answers by itself")
    }

    func testTheAppTakesItsRequestsBackWhenNobodyComes() {
        var gate = ExecutionGate()
        gate.expectExecutor(until: start.addingTimeInterval(5))
        XCTAssertTrue(hold("a", in: &gate, at: 1))

        let late = gate.expire(now: start.addingTimeInterval(5))
        XCTAssertEqual(late?.map(\.request.id), ["a"])
        XCTAssertNil(gate.deadline)
        XCTAssertFalse(hold("b", in: &gate, at: 5.1), "Nobody is expected anymore")
        XCTAssertNil(gate.expire(now: start.addingTimeInterval(6)), "Only once")
    }

    func testAWaitWithoutRequestStillEnds() {
        var gate = ExecutionGate()
        gate.expectExecutor(until: start.addingTimeInterval(5))
        XCTAssertEqual(gate.expire(now: start.addingTimeInterval(5.1))?.count, 0, "Nobody came, even if nothing was waiting")
    }

    func testAnInvitationExtendsTheWait() {
        var gate = ExecutionGate()
        gate.expectExecutor(until: start.addingTimeInterval(5))
        XCTAssertTrue(hold("a", in: &gate, at: 4))
        // The Mac invited the app at 4.5 s: the connection gets some more time.
        gate.expectExecutor(until: start.addingTimeInterval(12.5))

        XCTAssertNil(gate.expire(now: start.addingTimeInterval(5.1)), "The first timer finds a longer wait")
        XCTAssertTrue(hold("b", in: &gate, at: 8))
        // A shorter wait never replaces a longer one.
        gate.expectExecutor(until: start.addingTimeInterval(9))
        XCTAssertEqual(gate.deadline, start.addingTimeInterval(12.5))

        XCTAssertEqual(gate.expire(now: start.addingTimeInterval(12.6))?.map(\.request.id), ["a", "b"])
    }

    func testNothingIsExpectedWhileAMacIsThere() {
        var gate = ExecutionGate()
        _ = gate.executorArrived()
        gate.expectExecutor(until: start.addingTimeInterval(5))
        XCTAssertNil(gate.deadline)

        // It leaves: requests go back to the app right away, until a Mac is expected again.
        gate.executorLeft()
        XCTAssertFalse(hold("a", in: &gate, at: 1))
        gate.expectExecutor(until: start.addingTimeInterval(5))
        XCTAssertTrue(hold("b", in: &gate, at: 1))
    }

    func testCancelledRequestsStopWaiting() {
        var gate = ExecutionGate()
        gate.expectExecutor(until: start.addingTimeInterval(5))
        XCTAssertTrue(hold("a", in: &gate, at: 0))
        XCTAssertTrue(hold("b", in: &gate, at: 0))

        XCTAssertTrue(gate.cancel(id: "a"))
        XCTAssertFalse(gate.cancel(id: "a"))
        XCTAssertFalse(gate.cancel(id: "unknown"))
        XCTAssertEqual(gate.executorArrived().map(\.request.id), ["b"])
    }

    func testGivingUpReleasesEverything() {
        var gate = ExecutionGate()
        gate.expectExecutor(until: start.addingTimeInterval(5))
        XCTAssertTrue(hold("a", in: &gate, at: 0))

        XCTAssertEqual(gate.giveUp().map(\.request.id), ["a"])
        XCTAssertNil(gate.deadline)
        XCTAssertFalse(gate.hasExecutor)
        XCTAssertFalse(hold("b", in: &gate, at: 1))
        XCTAssertTrue(gate.giveUp().isEmpty)
    }
}
