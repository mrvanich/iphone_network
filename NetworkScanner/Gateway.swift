import Foundation
import Darwin

/// Шлюз за замовчуванням (IPv4) для інтерфейсу — зазвичай роутер.
enum Gateway {
    static func ipv4(interface: String = "en0") -> UInt32? {
        let ifIndex = Int(if_nametoindex(interface))
        var mib: [Int32] = [4, 17, 0, 2, 2, 0x2] // CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_GATEWAY
        var length = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0, length > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, UInt32(mib.count), &buf, &length, nil, 0) == 0 else { return nil }

        let header = 92
        var off = 0
        while off + header < length {
            let msgLen = Int(buf[off]) | (Int(buf[off + 1]) << 8)
            if msgLen < header || off + msgLen > length { break }
            let end = off + msgLen
            let index = Int(buf[off + 4]) | (Int(buf[off + 5]) << 8)
            let addrs = Int(buf[off + 12]) | (Int(buf[off + 13]) << 8)

            if (ifIndex == 0 || index == ifIndex), addrs & 1 != 0, addrs & 2 != 0 {
                var p = off + header
                if p + 8 <= end {
                    let dstLen = Int(buf[p])
                    let dstIsDefault = dstLen < 8 || (buf[p + 4] | buf[p + 5] | buf[p + 6] | buf[p + 7]) == 0
                    if dstIsDefault {
                        p += dstLen == 0 ? 4 : ((dstLen + 3) & ~3)
                        if p + 8 <= end, buf[p + 1] == 2 {
                            return (UInt32(buf[p + 4]) << 24) | (UInt32(buf[p + 5]) << 16)
                                 | (UInt32(buf[p + 6]) << 8) | UInt32(buf[p + 7])
                        }
                    }
                }
            }
            off = end
        }
        return nil
    }
}
