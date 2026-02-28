import Foundation
import Network

/// WebSocket server using NWListener, bound to localhost only.
final class WebSocketServer: @unchecked Sendable {
    private(set) var host: String
    private(set) var port: UInt16
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private let queue = DispatchQueue(label: "plasma.ws.server", qos: .userInitiated)
    private let lock = NSLock()

    /// Called on the main queue when a text message is received.
    var onMessage: ((String) -> Void)?

    /// Called on the main queue when the number of connected clients changes.
    var onClientCountChanged: ((Int) -> Void)?

    var clientCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return connections.count
    }

    init(host: String = "localhost", port: UInt16 = 9420) {
        self.host = host
        self.port = port
    }

    /// Stop, reconfigure, and restart the server on a new host/port.
    /// Calls completion on main queue with `true` on success, `false` on failure (rolling back).
    func restart(host: String, port: UInt16, completion: ((Bool) -> Void)? = nil) {
        let previousHost = self.host
        let previousPort = self.port
        stop()
        self.host = host
        self.port = port
        start { [weak self] success in
            if !success {
                // Rollback to previous config
                self?.stop()
                self?.host = previousHost
                self?.port = previousPort
                self?.start()
            }
            DispatchQueue.main.async {
                completion?(success)
            }
        }
    }

    func start(completion: ((Bool) -> Void)? = nil) {
        let params = NWParameters.tcp
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        // Bind to configured host
        let nwHost: NWEndpoint.Host
        if host == "localhost" || host == "127.0.0.1" {
            nwHost = NWEndpoint.Host("127.0.0.1")
        } else if host == "0.0.0.0" {
            nwHost = NWEndpoint.Host("0.0.0.0")
        } else {
            nwHost = NWEndpoint.Host(host)
        }
        params.requiredLocalEndpoint = NWEndpoint.hostPort(
            host: nwHost,
            port: NWEndpoint.Port(rawValue: port)!
        )

        do {
            listener = try NWListener(using: params)
        } catch {
            print("[WebSocket] Failed to create listener: \(error)")
            completion?(false)
            return
        }

        // Track whether completion has already fired (only fire once)
        var completionFired = false
        let fireLock = NSLock()

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[WebSocket] Listening on ws://\(self?.host ?? "?"):\(self?.port ?? 0)")
                fireLock.lock()
                let shouldFire = !completionFired
                completionFired = true
                fireLock.unlock()
                if shouldFire { completion?(true) }
            case .failed(let error):
                print("[WebSocket] Listener failed: \(error)")
                fireLock.lock()
                let shouldFire = !completionFired
                completionFired = true
                fireLock.unlock()
                if shouldFire { completion?(false) }
            case .cancelled:
                print("[WebSocket] Listener cancelled")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        lock.lock()
        let conns = connections
        connections.removeAll()
        lock.unlock()
        for (_, conn) in conns {
            conn.cancel()
        }
    }

    /// Send a text message to all connected clients.
    func sendToAll(_ text: String) {
        lock.lock()
        let conns = Array(connections.values)
        lock.unlock()

        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(
            identifier: "ws-text",
            metadata: [metadata]
        )

        for conn in conns {
            conn.send(
                content: text.data(using: .utf8),
                contentContext: context,
                isComplete: true,
                completion: .contentProcessed { error in
                    if let error {
                        print("[WebSocket] Send error: \(error)")
                    }
                }
            )
        }
    }

    // MARK: - Private

    private func handleNewConnection(_ connection: NWConnection) {
        let id = UUID()

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[WebSocket] Client connected: \(id)")
                self?.lock.lock()
                self?.connections[id] = connection
                let count = self?.connections.count ?? 0
                self?.lock.unlock()
                DispatchQueue.main.async {
                    self?.onClientCountChanged?(count)
                }

            case .failed(let error):
                print("[WebSocket] Client \(id) failed: \(error)")
                self?.removeConnection(id: id)

            case .cancelled:
                print("[WebSocket] Client \(id) disconnected")
                self?.removeConnection(id: id)

            default:
                break
            }
        }

        connection.start(queue: queue)
        receiveMessage(from: connection, id: id)
    }

    private func removeConnection(id: UUID) {
        lock.lock()
        connections.removeValue(forKey: id)
        let count = connections.count
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.onClientCountChanged?(count)
        }
    }

    private func receiveMessage(from connection: NWConnection, id: UUID) {
        connection.receiveMessage { [weak self] content, context, isComplete, error in
            if let error {
                print("[WebSocket] Receive error from \(id): \(error)")
                self?.removeConnection(id: id)
                return
            }

            if let content, !content.isEmpty {
                // Check if this is a WebSocket text frame
                let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition)
                    as? NWProtocolWebSocket.Metadata

                if metadata?.opcode == .close {
                    connection.cancel()
                    return
                }

                if let text = String(data: content, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self?.onMessage?(text)
                    }
                }
            }

            // Continue receiving
            self?.receiveMessage(from: connection, id: id)
        }
    }
}
