import Foundation
import Network
import Darwin

struct InterfaceAddresses {
    var ipv4: UInt32?
    var mask: UInt32?
    var ipv6: [String] = []
}

enum Interfaces {
    static func readAll() -> [String: InterfaceAddresses] {
        var result: [String: InterfaceAddresses] = [:]
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return result }
        defer { freeifaddrs(head) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            let ifa = entry.pointee
            guard let addr = ifa.ifa_addr else { continue }
            let name = String(cString: ifa.ifa_name)
            var item = result[name] ?? InterfaceAddresses()

            if addr.pointee.sa_family == sa_family_t(AF_INET), let mask = ifa.ifa_netmask {
                item.ipv4 = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                    UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
                }
                item.mask = mask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                    UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
                }
            } else if addr.pointee.sa_family == sa_family_t(AF_INET6) {
                var a = addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee.sin6_addr }
                var buf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                if inet_ntop(AF_INET6, &a, &buf, socklen_t(INET6_ADDRSTRLEN)) != nil {
                    item.ipv6.append(String(cString: buf))
                }
            }
            result[name] = item
        }
        return result
    }
}

@MainActor
final class NetworkStatus: ObservableObject {
    struct Info {
        var connection = "Немає мережі"
        var hasWiFi = false
        var ip: String?
        var mask: String?
        var cidr: String?
        var gateway: String?
        var firstHost: String?
        var lastHost: String?
        var broadcast: String?
        var ipv6: [String] = []
        var cellularIP: String?
        var isExpensive = false
        var isConstrained = false
    }

    @Published private(set) var info = Info()
    private let monitor = NWPathMonitor()
    private var started = false

    func start() {
        guard !started else { refresh(); return }
        started = true
        monitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        monitor.start(queue: .global(qos: .utility))
        refresh()
    }

    func refresh() {
        let path = monitor.currentPath
        var i = Info()

        if path.status != .satisfied {
            i.connection = "Немає мережі"
        } else if path.usesInterfaceType(.wifi) {
            i.connection = "Wi-Fi"
        } else if path.usesInterfaceType(.cellular) {
            i.connection = "Мобільна мережа"
        } else if path.usesInterfaceType(.wiredEthernet) {
            i.connection = "Ethernet"
        } else {
            i.connection = "Підключено"
        }
        i.isExpensive = path.isExpensive
        i.isConstrained = path.isConstrained

        let all = Interfaces.readAll()
        if let wifi = all["en0"], let ip = wifi.ipv4, let mask = wifi.mask {
            let net = LocalNetwork(ip: ip, netmask: mask)
            i.hasWiFi = true
            i.ip = IPv4.string(ip)
            i.mask = IPv4.string(mask)
            i.cidr = net.cidr
            i.broadcast = IPv4.string(net.broadcast)
            if net.broadcast > net.network &+ 1 {
                i.firstHost = IPv4.string(net.network &+ 1)
                i.lastHost = IPv4.string(net.broadcast &- 1)
            }
            if let gw = Gateway.ipv4(interface: "en0") { i.gateway = IPv4.string(gw) }
            i.ipv6 = wifi.ipv6
        }
        if let cell = all["pdp_ip0"], let ip = cell.ipv4 { i.cellularIP = IPv4.string(ip) }
        info = i
    }
}
