import Foundation

enum DeviceKind: Int {
    case hikvision, dahua, camera, other

    var isCamera: Bool { self != .other }
}

struct NetworkDevice: Identifiable, Hashable {
    var id: UInt32 { ipValue }
    let ipValue: UInt32
    var ip: String { IPv4.string(ipValue) }
    var mac: String?
    var vendor: String?
    var model: String
    var kind: DeviceKind
    var openPorts: [UInt16]
    var detail: String?
}
