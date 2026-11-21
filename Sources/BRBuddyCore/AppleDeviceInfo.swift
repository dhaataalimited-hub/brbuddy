import Foundation

/// Making sense of nearby Apple devices for the walk-away picker. Apple devices advertise anonymously (rotating
/// addresses, usually no name), so the picker filters by what kind of Continuity message a device broadcasts and,
/// after a brief connection, by the model it reports in its Device Information service.
public enum AppleDeviceInfo {
    /// Apple's Bluetooth company identifier, little-endian, at the start of its manufacturer data.
    public static let companyID: [UInt8] = [0x4C, 0x00]

    /// Continuity message types that phones, watches, iPads and Macs send (Nearby Info, Handoff, Nearby Action).
    /// Accessories send others: AirPods proximity pairing (0x07), Find My / AirTags (0x12), AirPlay (0x09).
    static let personalDeviceTypes: Set<UInt8> = [0x0C, 0x0F, 0x10]

    /// The Continuity message types in Apple manufacturer data (type, length, payload, repeated), or nil if it isn't
    /// Apple's.
    public static func messageTypes(manufacturerData data: Data) -> Set<UInt8>? {
        let bytes = [UInt8](data)
        guard bytes.count >= 2, Array(bytes.prefix(2)) == companyID else { return nil }
        var types = Set<UInt8>()
        var index = 2
        while index + 1 < bytes.count {
            types.insert(bytes[index])
            index += 2 + Int(bytes[index + 1])
        }
        return types
    }

    /// Whether this advertisement could be an iPhone or Apple Watch (or an iPad or Mac, which the model check then
    /// sorts out), rather than AirPods, an AirTag or an Apple TV.
    public static func isPersonalDevice(manufacturerData data: Data) -> Bool {
        guard let types = messageTypes(manufacturerData: data) else { return false }
        return !types.isDisjoint(with: personalDeviceTypes)
    }

    public enum Kind: String, Sendable {
        case iPhone, watch, iPad, mac, other

        public var title: String {
            switch self {
            case .iPhone: "iPhone"
            case .watch: "Apple Watch"
            case .iPad: "iPad"
            case .mac: "Mac"
            case .other: "Apple device"
            }
        }

        /// Worth offering for walk-away: something the user carries.
        public var isCarried: Bool { self == .iPhone || self == .watch }
    }

    /// The kind from a Device Information model number such as "iPhone15,2", "Watch6,1" or "MacBookPro18,3".
    public static func kind(model: String) -> Kind {
        if model.hasPrefix("iPhone") { return .iPhone }
        if model.hasPrefix("Watch") { return .watch }
        if model.hasPrefix("iPad") { return .iPad }
        if model.hasPrefix("Mac") || model.hasPrefix("iMac") { return .mac }
        return .other
    }
}

/// Whether a device chosen for walk-away is paired with this Mac. Walk-away needs pairing: an unpaired iPhone switches
/// to a new Bluetooth address about every 15 minutes and macOS gives each its own identifier, so BRBuddy would lose
/// it. Pairing (System Settings → Bluetooth) lets macOS follow it, and as a side effect apps then see the phone's own
/// name instead of "iPhone", which is how a picker row is matched to the paired list.
public enum WalkAwayPairing: Equatable, Sendable {
    case paired
    case notPaired
    /// Paired, but called just "iPhone", so it can't be told apart from strangers' unpaired iPhones.
    case genericName

    /// Names iPhones give unpaired Macs, and default device names.
    static let genericNames: Set<String> = ["iphone", "apple watch", "ipad"]

    /// - Parameters:
    ///   - name: the device's name as Bluetooth LE reports it (nil if none).
    ///   - pairedNames: names of the phones paired with this Mac.
    public static func status(name: String?, pairedNames: Set<String>) -> WalkAwayPairing {
        guard let name, !name.isEmpty else { return .notPaired }
        let isGeneric = genericNames.contains(name.lowercased())
        guard pairedNames.contains(name) else { return .notPaired }
        return isGeneric ? .genericName : .paired
    }

    /// The device's own name from a saved display title ("Andy's iPhone · 2EDA" → "Andy's iPhone").
    public static func baseName(ofTitle title: String) -> String {
        guard let range = title.range(of: " · ", options: .backwards) else { return title }
        return String(title[..<range.lowerBound])
    }
}
