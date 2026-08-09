import XCTest
import Network
@testable import ATVRemoteCore

/// A peer that accepts the connection and then behaves badly, the way the wrong
/// service on a guessed port does: it either says nothing at all, or announces a
/// frame body it never sends.
private final class SilentPeer {
    enum Behaviour {
        case sayNothing
        case headerThenSilence
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "silent.peer")
    private var connections: [NWConnection] = []
    private var hasSettled = false

    init(behaviour: Behaviour) throws {
        listener = try NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            self.connections.append(connection)
            connection.start(queue: self.queue)
            if behaviour == .headerThenSilence {
                connection.send(content: Self.headerAnnouncingSixteenBytes, completion: .idempotent)
            }
        }
    }

    /// Frame header: type 0, body length 16. The body never follows.
    private static let headerAnnouncingSixteenBytes = Data([0x00, 0x00, 0x00, 0x10])

    func start() async throws -> NWEndpoint.Port {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.listener.stateUpdateHandler = { state in
                    guard !self.hasSettled else { return }
                    switch state {
                    case .ready:
                        guard let port = self.listener.port else { return }
                        self.hasSettled = true
                        continuation.resume(returning: port)
                    case .failed(let error):
                        self.hasSettled = true
                        continuation.resume(throwing: error)
                    default:
                        break
                    }
                }
                self.listener.start(queue: self.queue)
            }
        }
    }

    func stop() {
        for connection in connections {
            connection.cancel()
        }
        listener.cancel()
    }
}

final class CompanionConnectionTests: XCTestCase {
    private let connectTimeout: UInt64 = 2_000_000_000
    private let receiveTimeout: UInt64 = 1_000_000_000

    func testReadTimesOutWhenPeerNeverAnswers() async throws {
        try await assertReadTimesOut(against: .sayNothing)
    }

    func testReadTimesOutWhenPeerAnnouncesABodyItNeverSends() async throws {
        try await assertReadTimesOut(against: .headerThenSilence)
    }

    private func assertReadTimesOut(
        against behaviour: SilentPeer.Behaviour,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let peer = try SilentPeer(behaviour: behaviour)
        let port = try await peer.start()
        defer { peer.stop() }

        let connection = CompanionConnection(
            connectTimeoutNanoseconds: connectTimeout,
            receiveTimeoutNanoseconds: receiveTimeout
        )
        try await connection.connect(to: .hostPort(host: .ipv4(.loopback), port: port))
        defer { connection.disconnect() }

        do {
            _ = try await connection.receiveFrame()
            XCTFail("expected the read to time out", file: file, line: line)
        } catch let error as CompanionConnectionError {
            XCTAssertEqual(error, .timeout, "a stalled peer must surface as a timeout", file: file, line: line)
        }
    }
}

extension CompanionConnectionError: @retroactive Equatable {
    public static func == (lhs: CompanionConnectionError, rhs: CompanionConnectionError) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}
