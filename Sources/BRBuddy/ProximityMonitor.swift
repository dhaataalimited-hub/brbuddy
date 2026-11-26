import BRBuddyCore
@preconcurrency import CoreBluetooth
import Observation

/// Watches the user's chosen iPhone or Apple Watch over Bluetooth and reports when it leaves. Also lists nearby Apple
/// devices for Settings' picker. Owned by `AppState`.
///
/// While watching, it stays connected to the device and reads its signal strength every 2 seconds (phones advertise
/// rarely when locked, so a connection gives steadier readings), reconnecting if the link drops. The readings go to
/// `ProximityTracker`, which decides near or away.
@MainActor
@Observable
final class ProximityMonitor: NSObject {
    struct Device: Identifiable, Equatable {
        var id: UUID
        /// The device's own name, when it shares one after connecting ("Andy's iPhone"); often nil.
        var name: String?
        /// From its Device Information model number, once read; nil until then.
        var kind: AppleDeviceInfo.Kind?
        /// Smoothed signal strength in dBm.
        var rssi: Double
        var lastSeen: Date

        /// What the picker shows: the name if known, else the kind and a short ID to tell devices apart.
        /// iPhones only give the generic name ("iPhone"), so the start of the Mac's ID for the device tells rows
        /// apart. It isn't the Bluetooth address (macOS doesn't share those) and only means something on this Mac.
        var title: String {
            "\(name ?? kind?.title ?? "Apple device") · \(id.uuidString.prefix(4))"
        }
    }

    var settings: ProximitySettings {
        didSet {
            settings.save()
            if settings.deviceID != oldValue.deviceID || settings.range != oldValue.range { tracker = ProximityTracker(range: settings.range) }
            update()
        }
    }

    /// Called when the watched device leaves.
    var onLeft: (() -> Void)?

    private(set) var bluetoothState: CBManagerState = .unknown
    /// Nearby phones and watches (and not-yet-identified Apple devices), strongest signal first.
    private(set) var nearbyDevices: [Device] = []
    /// The device clearly closest to the Mac (8 dB ahead of the next), so holding a phone against it picks it out.
    var closestDeviceID: UUID? {
        guard let first = nearbyDevices.first else { return nil }
        guard nearbyDevices.count > 1 else { return first.rssi > -50 ? first.id : nil }
        return first.rssi - nearbyDevices[1].rssi >= 8 ? first.id : nil
    }
    private(set) var tracker: ProximityTracker
    private(set) var isConnected = false
    /// A walk-away dry run in progress (Settings → Walk-away → Test), or nil.
    private(set) var test: WalkAwayTest?
    /// The watched device's name, if it shared one after connecting.
    var connectedName: String? { isConnected ? watched?.name : nil }


    /// Names of phones paired with this Mac (System Settings → Bluetooth). Walk-away only uses a paired phone.
    private(set) var pairedNames: Set<String> = []

    /// Rereads macOS's paired list (after the user pairs in System Settings, or when the picker opens).
    func refreshPairing() {
        guard Self.isAvailable else { return }
        pairedNames = PairedDevices.phoneNames()
    }

    func pairing(of device: Device) -> WalkAwayPairing {
        WalkAwayPairing.status(name: device.name, pairedNames: pairedNames)
    }

    /// Whether the saved device is a paired phone, so walk-away may act on it.
    var chosenPairing: WalkAwayPairing {
        guard let title = settings.deviceName, settings.deviceID != nil else { return .notPaired }
        return WalkAwayPairing.status(name: WalkAwayPairing.baseName(ofTitle: title), pairedNames: pairedNames)
    }

    /// Watching the chosen device: walk-away is on, or a test is running.
    private var isWatching: Bool { settings.isActive || (test != nil && settings.deviceID != nil) }

    private var central: CBCentralManager?
    private var watched: CBPeripheral?
    private var pickerOpen = false
    private var rssiTimer: Timer?
    private var tickTimer: Timer?
    /// Picker devices being briefly connected to, to read their model (and name, if they share it).
    private var probes: [UUID: CBPeripheral] = [:]
    private var probed: Set<UUID> = []
    private var allDevices: [UUID: Device] = [:]
    private static let maxProbes = 3
    nonisolated private static let deviceInformation = CBUUID(string: "180A")
    nonisolated private static let modelNumber = CBUUID(string: "2A24")

    override init() {
        let loaded = ProximitySettings.load()
        settings = loaded
        tracker = ProximityTracker(range: loaded.range)
        super.init()
        // Only read Bluetooth when walk-away is on (no surprise permission prompt otherwise).
        if loaded.isActive { refreshPairing() }
        update()
    }

    /// Bluetooth needs a usage description in the app bundle; without one (`swift run`) macOS would kill the app.
    static var isAvailable: Bool { Bundle.main.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") != nil }

    var statusText: String {
        switch bluetoothState {
        case .poweredOff: return "Bluetooth is off."
        case .unauthorized: return "BRBuddy isn't allowed to use Bluetooth (System Settings → Privacy & Security → Bluetooth)."
        case .unsupported: return "This Mac doesn't support Bluetooth LE."
        default: break
        }
        guard settings.deviceID != nil else { return "Pair your iPhone with this Mac, then choose it here." }
        guard chosenPairing == .paired else { return "This device isn't paired with this Mac, so walk-away is off." }
        guard settings.isActive else { return "Off." }
        let name = settings.deviceName ?? "Your device"
        switch tracker.state {
        case .near: return "\(name) is nearby\(tracker.smoothed.map { String(format: " (signal %.0f)", $0) } ?? "")."
        case .away: return "\(name) is away."
        case .unknown: return isConnected ? "Listening to \(name)…" : "Looking for \(name)…"
        }
    }

    // MARK: Picker

    /// Settings' device list is showing: scan for nearby Apple devices.
    func setPickerOpen(_ open: Bool) {
        pickerOpen = open
        if open { refreshPairing() }
        if !open {
            for peripheral in probes.values { central?.cancelPeripheralConnection(peripheral) }
            probes = [:]
            probed = []
            allDevices = [:]
            nearbyDevices = []
        }
        update()
    }

    /// Starts a dry run: watches the chosen device and reports near/away without starting BRB.
    func startTest() {
        guard settings.deviceID != nil else { return }
        tracker.reset()
        test = WalkAwayTest()
        update()
    }

    func stopTest() {
        test = nil
        if !settings.isActive { stopWatching() }
        update()
    }

    func choose(_ device: Device) {
        var s = settings
        s.deviceID = device.id.uuidString
        s.deviceName = device.title
        s.enabled = true
        settings = s
    }

    // MARK: Running

    /// Starts or stops Bluetooth work to match settings and the picker.
    private func update() {
        guard Self.isAvailable else { return }
        let needed = pickerOpen || isWatching
        if needed, central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
            return  // continues in centralManagerDidUpdateState
        }
        guard let central else { return }
        if !needed {
            stopWatching()
            if central.isScanning { central.stopScan() }
            return
        }
        guard central.state == .poweredOn else { return }
        if pickerOpen || (isWatching && !isConnected) {
            if !central.isScanning { central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]) }
        } else if central.isScanning {
            central.stopScan()
        }
        if isWatching {
            startWatching()
        } else {
            stopWatching()
        }
    }

    private func startWatching() {
        guard let central, let id = settings.deviceID.flatMap(UUID.init(uuidString:)) else { return }
        if watched?.identifier != id {
            refreshPairing()
            stopWatching()
            watched = central.retrievePeripherals(withIdentifiers: [id]).first
        }
        if let watched, watched.state == .disconnected { central.connect(watched) }
        if tickTimer == nil {
            tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if let change = self.tracker.tick(now: Date()) { self.handle(change) }
                    self.test?.observe(smoothed: self.tracker.smoothed, state: self.tracker.state)
                }
            }
        }
    }

    private func stopWatching() {
        if let watched, watched.state != .disconnected { central?.cancelPeripheralConnection(watched) }
        watched = nil
        isConnected = false
        rssiTimer?.invalidate(); rssiTimer = nil
        tickTimer?.invalidate(); tickTimer = nil
        tracker.reset()
    }

    private func record(rssi: Int) {
        if let change = tracker.add(rssi: Double(rssi), at: Date()) { handle(change) }
        test?.observe(smoothed: tracker.smoothed, state: tracker.state)
    }

    private func handle(_ state: ProximityTracker.State) {
        AppLog.info(.walkAway, "Device is now \(state)\(test != nil ? " (test)" : "")")
        if state == .away, settings.isActive, test == nil, chosenPairing == .paired { onLeft?() }
    }
}

extension ProximityMonitor: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        MainActor.assumeIsolated {
            AppLog.info(.walkAway, "Bluetooth state \(state.rawValue)")
            bluetoothState = state
            update()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let maker = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let personal = maker.map(AppleDeviceInfo.isPersonalDevice(manufacturerData:)) ?? false
        let id = peripheral.identifier
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let rssi = RSSI.intValue
        MainActor.assumeIsolated {
            if id.uuidString == settings.deviceID {
                record(rssi: rssi)
                if watched == nil || watched?.state == .disconnected { startWatching() }
            }
            guard pickerOpen, personal, rssi > -90, rssi < 0 else { return }
            var device = allDevices[id] ?? Device(id: id, name: nil, kind: nil, rssi: Double(rssi), lastSeen: Date())
            device.rssi = device.rssi * 0.7 + Double(rssi) * 0.3  // smooth, so the list doesn't jump around
            device.lastSeen = Date()
            if let name { device.name = name }
            allDevices[id] = device
            probeIfNeeded(peripheral)
            refreshNearby()
        }
    }

    /// Connects briefly to an unidentified device to read its model number. A few at a time, nearest first.
    private func probeIfNeeded(_ peripheral: CBPeripheral) {
        let id = peripheral.identifier
        guard let central, !probed.contains(id), probes.count < Self.maxProbes, id != watched?.identifier else { return }
        probed.insert(id)
        probes[id] = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
        // Give up on devices that don't answer (locked phones sometimes don't).
        Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.endProbe(id) }
        }
    }

    private func endProbe(_ id: UUID) {
        guard let peripheral = probes.removeValue(forKey: id) else { return }
        central?.cancelPeripheralConnection(peripheral)
    }

    /// Phones and watches (and devices not identified yet), strongest first; hides Macs and iPads, and devices not
    /// heard for 15 s.
    private func refreshNearby() {
        let now = Date()
        allDevices = allDevices.filter { now.timeIntervalSince($0.value.lastSeen) < 15 }
        nearbyDevices = allDevices.values
            .filter { $0.kind.map { $0.isCarried || $0 == .other } ?? true }
            .sorted { $0.rssi > $1.rssi }
    }
}

extension ProximityMonitor {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let service = peripheral.services?.first { $0.uuid == Self.deviceInformation }
        MainActor.assumeIsolated {
            guard probes[peripheral.identifier] != nil else { return }
            if let service {
                peripheral.discoverCharacteristics([Self.modelNumber], for: service)
            } else {
                endProbe(peripheral.identifier)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let characteristic = service.characteristics?.first { $0.uuid == Self.modelNumber }
        MainActor.assumeIsolated {
            guard probes[peripheral.identifier] != nil else { return }
            if let characteristic { peripheral.readValue(for: characteristic) } else { endProbe(peripheral.identifier) }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let model = characteristic.value.map { String(decoding: $0, as: UTF8.self) }
        let name = peripheral.name
        MainActor.assumeIsolated {
            let id = peripheral.identifier
            guard probes[id] != nil else { return }
            if var device = allDevices[id] {
                if let model { device.kind = AppleDeviceInfo.kind(model: model) }
                if let name, !name.isEmpty { device.name = name }
                allDevices[id] = device
                refreshNearby()
            }
            endProbe(id)
        }
    }
}

extension ProximityMonitor {
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            if probes[peripheral.identifier] != nil, peripheral.identifier != watched?.identifier {
                peripheral.discoverServices([Self.deviceInformation])
                return
            }
            guard peripheral.identifier == watched?.identifier else { return }
            isConnected = true
            peripheral.delegate = self
            peripheral.readRSSI()
            rssiTimer?.invalidate()
            rssiTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak peripheral] _ in peripheral?.readRSSI() }
            update()  // stop scanning if only the picker needed it
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            guard peripheral.identifier == watched?.identifier else { return }
            isConnected = false
            rssiTimer?.invalidate(); rssiTimer = nil
            update()  // scan again and reconnect when it's back in range
            if isWatching { central.connect(peripheral) }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            if probes[peripheral.identifier] != nil { probes[peripheral.identifier] = nil }
            guard peripheral.identifier == watched?.identifier else { return }
            isConnected = false
            update()
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        let rssi = RSSI.intValue
        guard error == nil else { return }
        MainActor.assumeIsolated { record(rssi: rssi) }
    }
}
