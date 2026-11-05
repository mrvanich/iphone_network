import Foundation
import Darwin

/// Читає системну ARP-таблицю (IP -> MAC). Працює «за можливості»:
/// iOS не гарантує доступ, тому при невдачі просто повертається порожній словник.
/// Викликати слід ПІСЛЯ спроб підключення до хостів — тоді ARP-кеш заповнений.
enum ARPTable {
    static func read() -> [UInt32: String] {
        // CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_LLINFO
        var mib: [Int32] = [4, 17, 0, 2, 2, 0x400]
        var length = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0, length > 0 else { return [:] }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &length, nil, 0) == 0 else { return [:] }

        let headerSize = 92 // sizeof(struct rt_msghdr) на Darwin
        var result: [UInt32: String] = [:]
        var offset = 0

        while offset + headerSize < length {
            let msgLen = Int(buffer[offset]) | (Int(buffer[offset + 1]) << 8)
            if msgLen < headerSize || offset + msgLen > length { break }
            let end = offset + msgLen
            let sin = offset + headerSize

            if sin + 8 <= end, buffer[sin + 1] == UInt8(AF_INET) {
                let ip = (UInt32(buffer[sin + 4]) << 24) | (UInt32(buffer[sin + 5]) << 16)
                       | (UInt32(buffer[sin + 6]) << 8) | UInt32(buffer[sin + 7])
                let sinLen = max(Int(buffer[sin]), 16)
                let sdl = sin + ((sinLen + 3) & ~3)

                if sdl + 8 <= end, buffer[sdl + 1] == 18 /* AF_LINK */ {
                    let nameLen = Int(buffer[sdl + 5])
                    let addrLen = Int(buffer[sdl + 6])
                    let macStart = sdl + 8 + nameLen
                    if addrLen == 6, macStart + 6 <= end {
                        let bytes = buffer[macStart..<(macStart + 6)]
                        if bytes.contains(where: { $0 != 0 }) {
                            result[ip] = bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
                        }
                    }
                }
            }
            offset += msgLen
        }
        return result
    }
}
