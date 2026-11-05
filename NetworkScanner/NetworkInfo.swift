import Foundation
import Darwin

enum IPv4 {
    static func string(_ v: UInt32) -> String {
        "\((v >> 24) & 255).\((v >> 16) & 255).\((v >> 8) & 255).\(v & 255)"
    }
}

/// Параметри поточної Wi-Fi мережі (інтерфейс en0).
struct LocalNetwork {
    let ip: UInt32
    let netmask: UInt32

    var network: UInt32 { ip & netmask }
    var broadcast: UInt32 { network | ~netmask }
    var prefixLength: Int { netmask.nonzeroBitCount }
    var cidr: String { "\(IPv4.string(network))/\(prefixLength)" }
    var ipString: String { IPv4.string(ip) }

    /// Адреси хостів підмережі (без мережі, broadcast і власної адреси).
    /// Для великих мереж (/16 тощо) обмежуємось вікном навколо власної адреси.
    func hostAddresses(limit: Int = 1022) -> [UInt32] {
        let first = network &+ 1
        let last = broadcast &- 1
        guard last >= first else { return [] }
        var lo = first
        var hi = last
        if Int(hi - lo) + 1 > limit {
            let half = UInt32(limit / 2)
            lo = max(first, ip > half ? ip - half : 0)
            hi = min(last, lo + UInt32(limit) - 1)
        }
        return (lo...hi).filter { $0 != ip }
    }

    static func current() -> LocalNetwork? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            let ifa = entry.pointee
            guard let addr = ifa.ifa_addr,
                  let mask = ifa.ifa_netmask,
                  addr.pointee.sa_family == sa_family_t(AF_INET),
                  String(cString: ifa.ifa_name) == "en0" else { continue }

            let ip = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            let nm = mask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            return LocalNetwork(ip: ip, netmask: nm)
        }
        return nil
    }
}
