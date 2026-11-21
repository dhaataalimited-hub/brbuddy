import IOBluetooth

/// Phones paired with this Mac in System Settings → Bluetooth, read from macOS's paired-device list. Needs the
/// app's Bluetooth permission, which walk-away already asks for.
enum PairedDevices {
    /// Names of paired phones (Bluetooth major class "phone").
    static func phoneNames() -> Set<String> {
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        return Set(devices.filter { $0.deviceClassMajor == UInt32(kBluetoothDeviceClassMajorPhone) }.compactMap(\.name))
    }

    /// Opens System Settings → Bluetooth, where the user pairs their iPhone.
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings")!
}
