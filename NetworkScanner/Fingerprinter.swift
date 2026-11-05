import Foundation

struct Fingerprint {
    var kind: DeviceKind = .other
    var vendor: String?
    var model: String = "Невідомий пристрій"
    var detail: String?
}

/// Визначає тип пристрою за відкритими портами та HTTP-відповідями (без логіна/пароля).
enum Fingerprinter {
    static func identify(ip: UInt32, openPorts: [UInt16]) async -> Fingerprint {
        let ports = Set(openPorts)
        var hikHit = false
        var dahuaHit = false
        var hikModel: String?
        var dahuaSerial: String?
        var server: String?
        var title: String?

        if let webPort = [UInt16(80), 8080].first(where: { ports.contains($0) }) {
            async let root = Net.httpGet(ip: ip, port: webPort, path: "/")
            async let hik = Net.httpGet(ip: ip, port: webPort, path: "/ISAPI/System/deviceInfo")
            async let dahua = Net.httpGet(ip: ip, port: webPort, path: "/cgi-bin/magicBox.cgi?action=getDeviceType")
            let (r1, r2, r3) = await (root, hik, dahua)

            if let r = r1 {
                server = HTTP.header("Server", in: r)
                title = HTTP.title(r)
                if let s = server?.lowercased(), s.contains("app-webs") || s.contains("dnvrs-webs") {
                    hikHit = true
                }
            }
            if let r = r2 {
                let st = HTTP.status(r)
                let realm = HTTP.realm(r)
                if st == 200, r.contains("DeviceInfo") {
                    hikHit = true
                } else if st == 401, let realm,
                          realm.range(of: #"^i?DS-"#, options: [.regularExpression, .caseInsensitive]) != nil {
                    hikHit = true
                    hikModel = realm
                }
            }
            if let r = r3 {
                let st = HTTP.status(r)
                let realm = HTTP.realm(r)
                if st == 200, r.contains("type=") {
                    dahuaHit = true
                } else if st == 401, let realm, realm.hasPrefix("Login to") {
                    dahuaHit = true
                    dahuaSerial = String(realm.dropFirst("Login to".count)).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        // Фірмові порти: 37777 — Dahua; 8000 разом із RTSP — зазвичай Hikvision.
        if ports.contains(37777) { dahuaHit = true }
        if ports.contains(8000), ports.contains(554), !dahuaHit { hikHit = true }

        var fp = Fingerprint()
        if hikHit && !(dahuaHit && hikModel == nil) {
            fp.kind = .hikvision
            fp.vendor = "Hikvision"
            fp.model = hikModel ?? "Hikvision камера / NVR"
        } else if dahuaHit {
            fp.kind = .dahua
            fp.vendor = "Dahua"
            fp.model = "Dahua камера / NVR"
            if let s = dahuaSerial, !s.isEmpty { fp.detail = "S/N: \(s)" }
        } else if ports.contains(554) {
            fp.kind = .camera
            fp.model = title ?? "RTSP-пристрій (камера/реєстратор)"
        } else {
            fp.model = title ?? server ?? "Невідомий пристрій"
        }

        if let server, fp.detail == nil { fp.detail = "Server: \(server)" }
        return fp
    }
}
