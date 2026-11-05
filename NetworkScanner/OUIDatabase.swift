import Foundation

/// Невелика вбудована база OUI (перші 3 байти MAC). Не вичерпна — доповнюйте за потреби.
enum OUI {
    private static let table: [String: String] = [
        // Hikvision
        "4419B6": "Hikvision", "BCAD28": "Hikvision", "101D1C": "Hikvision",
        "C056E3": "Hikvision", "2857BE": "Hikvision", "54C415": "Hikvision",
        "A41437": "Hikvision", "1868CB": "Hikvision", "240F9B": "Hikvision",
        "2CA59C": "Hikvision", "C42F90": "Hikvision", "8CE748": "Hikvision",
        // Dahua
        "3CEF8C": "Dahua", "4C11BF": "Dahua", "9002A9": "Dahua", "E0508B": "Dahua",
        "A0BD1D": "Dahua", "9C1463": "Dahua", "BC325F": "Dahua", "14A78B": "Dahua",
        "38AF29": "Dahua", "08EDED": "Dahua", "B4A2EB": "Dahua",
        // Інше
        "0018AE": "TVT (OEM DVR)",
        "001132": "Synology", "00089B": "QNAP",
        "B827EB": "Raspberry Pi", "DCA632": "Raspberry Pi", "E45F01": "Raspberry Pi",
        "18A6F7": "TP-Link", "0014D1": "TRENDnet", "D46E0E": "Tenda",
        "000C29": "VMware", "005056": "VMware",
        "F492BF": "Ubiquiti", "7483C2": "Ubiquiti", "B4FBE4": "Ubiquiti"
    ]

    static func vendor(for mac: String) -> String? {
        let clean = mac.replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
        guard clean.count >= 6 else { return nil }
        return table[String(clean.prefix(6))]
    }
}
