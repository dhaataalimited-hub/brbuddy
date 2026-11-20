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
        var name: String
        var rssi: Int
        var lastSeen: Date
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
    private(set) var nearbyDevices: [Device] = []
    private(set) var tracker: ProximityTracker
    private(set) var isConnected = false

    private var central: CBCentralManager?
    private var watched: CBPeripheral?
    private var pickerOpen = false
    private var rssiTimer: Timer?
    private var tickTimer: Timer?

    /// Apple's Bluetooth company identifier, at the start of iPhone/Watch manufacturer data.
    private static let appleCompanyID: [UInt8] = [0x4C, 0x00]

    override init() {
        let loaded = ProximitySettings.load()
        settings = loaded
        tracker = ProximityTracker(range: loaded.range)
        super.init()
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
        guard settings.isActive else { return settings.deviceID == nil ? "Pick your iPhone or Apple Watch below." : "Off." }
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
        if !open { nearbyDevices = [] }
        update()
    }

    func choose(_ device: Device) {
        var s = settings
        s.deviceID = device.id.uuidString
        s.deviceName = device.name
        s.enabled = true
        settings = s
    }

    // MARK: Running

    /// Starts or stops Bluetooth work to match settings and the picker.
    private func update() {
        guard Self.isAvailable else { return }
        let needed = pickerOpen || settings.isActive
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
        if pickerOpen || (settings.isActive && !isConnected) {
            if !central.isScanning { central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]) }
        } else if central.isScanning {
            central.stopScan()
        }
        if settings.isActive {
            startWatching()
        } else {
            stopWatching()
        }
    }

    private func startWatching() {
        guard let central, let id = settings.deviceID.flatMap(UUID.init(uuidString:)) else { return }
        if watched?.identifier != id {
            stopWatching()
            watched = central.retrievePeripherals(withIdentifiers: [id]).first
        }
        if let watched, watched.state == .disconnected { central.connect(watched) }
        if tickTimer == nil {
            tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let change = self.tracker.tick(now: Date()) else { return }
                    self.handle(change)
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
    }

    private func handle(_ state: ProximityTracker.State) {
        if state == .away, settings.isActive { onLeft?() }
    }
}

extension ProximityMonitor: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        MainActor.assumeIsolated {
            bluetoothState = state
            update()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let maker = (advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data).map { Array($0.prefix(2)) }
        let id = peripheral.identifier
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let rssi = RSSI.intValue
        MainActor.assumeIsolated {
            if id.uuidString == settings.deviceID {
                record(rssi: rssi)
                if watched == nil || watched?.state == .disconnected { startWatching() }
            }
            guard pickerOpen, maker == Self.appleCompanyID, rssi > -90, rssi < 0 else { return }
            let device = Device(id: id, name: name ?? "Apple device \(id.uuidString.prefix(4))", rssi: rssi, lastSeen: Date())
            if let index = nearbyDevices.firstIndex(where: { $0.id == id }) {
                nearbyDevices[index] = Device(id: id, name: name ?? nearbyDevices[index].name, rssi: rssi, lastSeen: Date())
            } else {
                nearbyDevices.append(device)
            }
            // Named devices first, then strongest; forget ones not heard for 15 s.
            nearbyDevices = nearbyDevices.filter { Date().timeIntervalSince($0.lastSeen) < 15 }
                .sorted { a, b in
                    let aUnnamed = a.name.hasPrefix("Apple device"), bUnnamed = b.name.hasPrefix("Apple device")
                    return aUnnamed == bUnnamed ? a.rssi > b.rssi : !aUnnamed
                }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
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
            if settings.isActive { central.connect(peripheral) }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
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
