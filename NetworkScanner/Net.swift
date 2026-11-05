import Foundation
import Network

private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    func fire(_ block: () -> Void) {
        lock.lock()
        let first = !fired
        fired = true
        lock.unlock()
        if first { block() }
    }
}

private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    func append(_ d: Data) { lock.lock(); data.append(d); lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return data.count }
    var snapshot: Data { lock.lock(); defer { lock.unlock() }; return data }
}

enum Net {
    private static let queue = DispatchQueue.global(qos: .userInitiated)
    private static let closedCodes: Set<POSIXErrorCode> = [.ECONNREFUSED, .EHOSTUNREACH, .ENETUNREACH, .EHOSTDOWN]

    /// TCP-перевірка: чи відкритий порт.
    static func isPortOpen(ip: UInt32, port: UInt16, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                cont.resume(returning: false)
                return
            }
            let conn = NWConnection(host: NWEndpoint.Host(IPv4.string(ip)), port: nwPort, using: .tcp)
            let once = Once()
            let finish: @Sendable (Bool) -> Void = { result in
                once.fire {
                    conn.cancel()
                    cont.resume(returning: result)
                }
            }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true)
                case .failed:
                    finish(false)
                case .waiting(let err):
                    if case .posix(let code) = err, closedCodes.contains(code) { finish(false) }
                default:
                    break
                }
            }
            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { finish(false) }
        }
    }

    /// Простий HTTP/1.0 GET поверх TCP (без ATS і без авторизації — потрібні лише заголовки).
    static func httpGet(ip: UInt32, port: UInt16, path: String, timeout: TimeInterval = 2.0) async -> String? {
        await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                cont.resume(returning: nil)
                return
            }
            let host = IPv4.string(ip)
            let conn = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
            let once = Once()
            let box = DataBox()

            let finish: @Sendable () -> Void = {
                once.fire {
                    conn.cancel()
                    let text = String(decoding: box.snapshot, as: UTF8.self)
                    cont.resume(returning: text.hasPrefix("HTTP/") ? text : nil)
                }
            }

            @Sendable func receiveLoop() {
                conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
                    if let data, !data.isEmpty { box.append(data) }
                    if isComplete || error != nil || box.count >= 8192 {
                        finish()
                    } else {
                        receiveLoop()
                    }
                }
            }

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let request = "GET \(path) HTTP/1.0\r\nHost: \(host)\r\nUser-Agent: NetworkScanner/1.0\r\nAccept: */*\r\nConnection: close\r\n\r\n"
                    conn.send(content: Data(request.utf8), completion: .contentProcessed({ _ in }))
                    receiveLoop()
                case .failed:
                    finish()
                case .waiting(let err):
                    if case .posix(let code) = err, closedCodes.contains(code) { finish() }
                default:
                    break
                }
            }
            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { finish() }
        }
    }
}

/// Розбір HTTP-відповіді.
enum HTTP {
    static func status(_ r: String) -> Int? {
        guard let line = r.components(separatedBy: "\r\n").first else { return nil }
        let parts = line.split(separator: " ")
        return parts.count >= 2 ? Int(parts[1]) : nil
    }

    static func header(_ name: String, in r: String) -> String? {
        let prefix = name.lowercased() + ":"
        for line in r.components(separatedBy: "\r\n") {
            if line.isEmpty { break }
            if line.lowercased().hasPrefix(prefix) {
                return line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    static func realm(_ r: String) -> String? {
        guard let a = r.range(of: "realm=\"", options: .caseInsensitive) else { return nil }
        let rest = r[a.upperBound...]
        guard let b = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<b])
    }

    static func title(_ r: String) -> String? {
        guard let a = r.range(of: "<title>", options: .caseInsensitive),
              let b = r.range(of: "</title>", options: .caseInsensitive, range: a.upperBound..<r.endIndex) else { return nil }
        let t = r[a.upperBound..<b.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : String(t.prefix(60))
    }
}

// MARK: - POST (для ONVIF/SOAP)
extension Net {
    static func httpPost(ip: UInt32, port: UInt16, path: String, body: String,
                         contentType: String, timeout: TimeInterval = 2.5) async -> String? {
        await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                cont.resume(returning: nil)
                return
            }
            let host = IPv4.string(ip)
            let conn = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
            let once = Once()
            let box = DataBox()
            let bodyData = Data(body.utf8)

            let finish: @Sendable () -> Void = {
                once.fire {
                    conn.cancel()
                    let text = String(decoding: box.snapshot, as: UTF8.self)
                    cont.resume(returning: text.hasPrefix("HTTP/") ? text : nil)
                }
            }

            @Sendable func receiveLoop() {
                conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, isComplete, error in
                    if let data, !data.isEmpty { box.append(data) }
                    if isComplete || error != nil || box.count >= 32768 {
                        finish()
                    } else {
                        receiveLoop()
                    }
                }
            }

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let head = "POST \(path) HTTP/1.0\r\nHost: \(host)\r\nContent-Type: \(contentType)\r\nContent-Length: \(bodyData.count)\r\nConnection: close\r\n\r\n"
                    var packet = Data(head.utf8)
                    packet.append(bodyData)
                    conn.send(content: packet, completion: .contentProcessed({ _ in }))
                    receiveLoop()
                case .failed:
                    finish()
                case .waiting(let err):
                    if case .posix(let code) = err, closedCodes.contains(code) { finish() }
                default:
                    break
                }
            }
            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { finish() }
        }
    }
}
