/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app delegate that sets up and starts the virtual machine.
*/

import Virtualization
import CryptoKit
import Foundation


let bundleExt = ".bundle"

protocol VMDevices {
    func addUSBDevice(_ sender: AnyObject?)
    func removeUSBDevice(_ sender: AnyObject?)
}

@main
class VMWindowDelegate: NSObject, NSApplicationDelegate, VZVirtualMachineDelegate, USBWatcherDelegate {
    private var vmData:VMData
    @IBOutlet weak var DevicesMenu: NSMenu!
    @IBOutlet weak var wizard: NSWindow!
    
    @IBOutlet var window: NSWindow!
    
    @IBOutlet weak var virtualMachineView: VZVirtualMachineView!
    
    private var virtualMachine: VZVirtualMachine!
    private var usbWatcher: USBWatcher!

    override init() {
        self.vmData = VMDefaultLinux()
        self.usbWatcher = nil
        super.init()
    }
    
    private func bundlePath() -> String {
        let result = vmPath + "/" + self.vmData.bundleName + bundleExt
        return result
    }
    
    private func machineIdentifierPath() -> String {
        let result = self.bundlePath() + "/" + self.vmData.machineIdentifierPath
        return result
    }
    
    private func efiVariableStorePath() -> String {
        let result = self.bundlePath() + "/" + "NVRAM"
        return result
    }
    
    private func mainDiskImagePath() -> String {
        let result = self.bundlePath() + "/" + self.vmData.diskImagePath
        return result
    }
    
    private func createVMBundle(atPath vmBundlePath: String) {
        do {
            try FileManager.default.createDirectory(atPath: vmBundlePath, withIntermediateDirectories: false)
        } catch {
            fatalError("Failed to create “GUI Linux VM.bundle.”")
        }
    }

    // Create an empty disk image for the virtual machine.
    private func createMainDiskImage(atPath mainDiskImagePath:String) {
        let diskCreated = FileManager.default.createFile(atPath: mainDiskImagePath, contents: nil, attributes: nil)
        if !diskCreated {
            fatalError("Failed to create the main disk image.")
        }

        guard let mainDiskFileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: mainDiskImagePath)) else {
            fatalError("Failed to get the file handle for the main disk image.")
        }

        do {
            // 64 GB disk space.
            try mainDiskFileHandle.truncate(atOffset: 64 * 1024 * 1024 * 1024)
        } catch {
            fatalError("Failed to truncate the main disk image.")
        }
    }

    // MARK: Create device configuration objects for the virtual machine.

    private func createBlockDeviceConfiguration() -> VZVirtioBlockDeviceConfiguration {
        guard let mainDiskAttachment = try? VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: self.mainDiskImagePath()), readOnly: false) else {
            fatalError("Failed to create main disk attachment.")
        }

        let mainDisk = VZVirtioBlockDeviceConfiguration(attachment: mainDiskAttachment)
        return mainDisk
    }

    private func computeCPUCount() -> Int {
        let totalAvailableCPUs = ProcessInfo.processInfo.processorCount
        var virtualCPUCount = self.vmData.cpus
        virtualCPUCount = min(virtualCPUCount, totalAvailableCPUs - 1)
        virtualCPUCount = max(virtualCPUCount, 1)

        virtualCPUCount = max(virtualCPUCount, VZVirtualMachineConfiguration.minimumAllowedCPUCount)
        virtualCPUCount = min(virtualCPUCount, VZVirtualMachineConfiguration.maximumAllowedCPUCount)
        
        return virtualCPUCount
    }

    private func computeMemorySize() -> UInt64 {
        var memorySize = UInt64(self.vmData.memory)
        memorySize = max(memorySize, VZVirtualMachineConfiguration.minimumAllowedMemorySize)
        memorySize = min(memorySize, VZVirtualMachineConfiguration.maximumAllowedMemorySize)

        return memorySize
    }

    private func createAndSaveMachineIdentifier() -> VZGenericMachineIdentifier {
        let machineIdentifier = VZGenericMachineIdentifier()

        // Store the machine identifier to disk so you can retrieve it for subsequent boots.
        try! machineIdentifier.dataRepresentation.write(to: URL(fileURLWithPath: self.machineIdentifierPath()))
        return machineIdentifier
    }

    private func retrieveMachineIdentifier() -> VZGenericMachineIdentifier {
        // Retrieve the machine identifier.
        guard let machineIdentifierData = try? Data(contentsOf: URL(fileURLWithPath: self.machineIdentifierPath())) else {
            fatalError("Failed to retrieve the machine identifier data.")
        }

        guard let machineIdentifier = VZGenericMachineIdentifier(dataRepresentation: machineIdentifierData) else {
            fatalError("Failed to create the machine identifier.")
        }

        return machineIdentifier
    }

    private func createEFIVariableStore() -> VZEFIVariableStore {
        guard let efiVariableStore = try? VZEFIVariableStore(creatingVariableStoreAt: URL(fileURLWithPath: self.efiVariableStorePath())) else {
            fatalError("Failed to create the EFI variable store.")
        }

        return efiVariableStore
    }

    private func retrieveEFIVariableStore() -> VZEFIVariableStore {
        if !FileManager.default.fileExists(atPath: self.efiVariableStorePath()) {
            fatalError("EFI variable store does not exist.")
        }

        return VZEFIVariableStore(url: URL(fileURLWithPath: self.efiVariableStorePath()))
    }

    private func createUSBMassStorageDeviceConfiguration() -> VZUSBMassStorageDeviceConfiguration {
        guard let intallerDiskAttachment = try? VZDiskImageStorageDeviceAttachment(url: self.vmData.installerISOPath!, readOnly: true) else {
            fatalError("Failed to create installer's disk attachment.")
        }

        return VZUSBMassStorageDeviceConfiguration(attachment: intallerDiskAttachment)
    }

    private func createNetworkDeviceConfiguration() -> VZVirtioNetworkDeviceConfiguration {
        let networkDevice = VZVirtioNetworkDeviceConfiguration()
        networkDevice.attachment = VZNATNetworkDeviceAttachment()

        return networkDevice
    }
    
    @available(macOS 15.0, *)
    private func createUSBDeviceConfiguration() -> [VZUSBControllerConfiguration] {
        let usbControllers = VZXHCIControllerConfiguration()
        return [usbControllers]
    }

    private func createGraphicsDeviceConfiguration() -> VZVirtioGraphicsDeviceConfiguration {
        let graphicsDevice = VZVirtioGraphicsDeviceConfiguration()
        graphicsDevice.scanouts = [
            VZVirtioGraphicsScanoutConfiguration(widthInPixels: 1280, heightInPixels: 720)
        ]

        return graphicsDevice
    }

    private func createInputAudioDeviceConfiguration() -> VZVirtioSoundDeviceConfiguration {
        let inputAudioDevice = VZVirtioSoundDeviceConfiguration()

        let inputStream = VZVirtioSoundDeviceInputStreamConfiguration()
        inputStream.source = VZHostAudioInputStreamSource()

        inputAudioDevice.streams = [inputStream]
        return inputAudioDevice
    }

    private func createOutputAudioDeviceConfiguration() -> VZVirtioSoundDeviceConfiguration {
        let outputAudioDevice = VZVirtioSoundDeviceConfiguration()

        let outputStream = VZVirtioSoundDeviceOutputStreamConfiguration()
        outputStream.sink = VZHostAudioOutputStreamSink()

        outputAudioDevice.streams = [outputStream]
        return outputAudioDevice
    }

    private func createSpiceAgentConsoleDeviceConfiguration() -> VZVirtioConsoleDeviceConfiguration {
        let consoleDevice = VZVirtioConsoleDeviceConfiguration()

        let spiceAgentPort = VZVirtioConsolePortConfiguration()
        spiceAgentPort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
        spiceAgentPort.attachment = VZSpiceAgentPortAttachment()
        consoleDevice.ports[0] = spiceAgentPort
        print("Spice port successfully configured")
        
        return consoleDevice
    }

    // MARK: Create the virtual machine configuration and instantiate the virtual machine.

    func createVirtualMachine() {
        let virtualMachineConfiguration = VZVirtualMachineConfiguration()

        virtualMachineConfiguration.cpuCount = computeCPUCount()
        virtualMachineConfiguration.memorySize = computeMemorySize()

        let platform = VZGenericPlatformConfiguration()
        let bootloader = VZEFIBootLoader()
        let disksArray = NSMutableArray()

        if self.vmData.needsInstall {
            // This is a fresh install: Create a new machine identifier and EFI variable store,
            // and configure a USB mass storage device to boot the ISO image.
            platform.machineIdentifier = createAndSaveMachineIdentifier()
            bootloader.variableStore = createEFIVariableStore()
            disksArray.add(createUSBMassStorageDeviceConfiguration())
        } else {
            // The VM is booting from a disk image that already has the OS installed.
            // Retrieve the machine identifier and EFI variable store that were saved to
            // disk during installation.
            platform.machineIdentifier = retrieveMachineIdentifier()
            bootloader.variableStore = retrieveEFIVariableStore()
        }

        virtualMachineConfiguration.platform = platform
        virtualMachineConfiguration.bootLoader = bootloader

        disksArray.add(createBlockDeviceConfiguration())
        guard let disks = disksArray as? [VZStorageDeviceConfiguration] else {
            fatalError("Invalid disksArray.")
        }
        virtualMachineConfiguration.storageDevices = disks

        virtualMachineConfiguration.networkDevices = [createNetworkDeviceConfiguration()]
        virtualMachineConfiguration.graphicsDevices = [createGraphicsDeviceConfiguration()]
        virtualMachineConfiguration.audioDevices = [createInputAudioDeviceConfiguration(), createOutputAudioDeviceConfiguration()]

        virtualMachineConfiguration.keyboards = [VZUSBKeyboardConfiguration()]
        virtualMachineConfiguration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        virtualMachineConfiguration.consoleDevices = [self.createSpiceAgentConsoleDeviceConfiguration()]
        if #available(macOS 15.0, *) {
            virtualMachineConfiguration.usbControllers = self.createUSBDeviceConfiguration()
        }

        try! virtualMachineConfiguration.validate()
        self.virtualMachine = VZVirtualMachine(configuration: virtualMachineConfiguration)
    }

    // MARK: Start the virtual machine.

    func configureAndStartVirtualMachine() {
        DispatchQueue.main.async {
            self.createVirtualMachine()
            self.virtualMachineView.virtualMachine = self.virtualMachine

            if #available(macOS 14.0, *) {
                // Configure the app to automatically respond changes in the display size.
                self.virtualMachineView.automaticallyReconfiguresDisplay = true
            }

            self.virtualMachine.delegate = self
            self.virtualMachine.start(completionHandler: { (result) in
                switch result {
                case let .failure(error):
                    fatalError("Virtual machine failed to start with error: \(error)")
                default:
                    print("Virtual machine successfully started.")
                    print("USB detected devices:")
                    if #available(macOS 15.0, *) {
                        for usbController in self.virtualMachine.usbControllers.publisher.sequence {
                            print("className=\(usbController.className); classDescription=\(usbController.classDescription)")
                            for device in usbController.usbDevices {
                                print("uuid=\(device.uuid); description=\(device.description)")
                            }
                        }
                    }
                }
            })
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.usbWatcher = USBWatcher(delegate: self)
        NSApp.activate(ignoringOtherApps: true)

        // If "GUI Linux VM.bundle" doesn't exist, the sample app tries to create
        // one and install Linux onto an empty disk image from the ISO image,
        // otherwise, it tries to directly boot from the disk image inside
        // the "GUI Linux VM.bundle".
        let bundlePath = self.bundlePath()
        if !FileManager.default.fileExists(atPath: bundlePath) {
            self.vmData.needsInstall = true
            createVMBundle(atPath: bundlePath)
            createMainDiskImage(atPath: self.mainDiskImagePath())

            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = true
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = false
            openPanel.canCreateDirectories = false

            openPanel.begin { (result) -> Void in
                if result == .OK {
                    self.vmData.installerISOPath = openPanel.url!
                    self.configureAndStartVirtualMachine()
                } else {
                    fatalError("ISO file not selected.")
                }
            }
        } else {
            self.vmData.needsInstall = false
            configureAndStartVirtualMachine()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: VZVirtualMachineDelegate methods.

    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        print("Virtual machine did stop with error: \(error.localizedDescription)")
        exit(-1)
    }

    func completionNilHandler(_ err: Error?) -> Void {
        print("completionNilHandler")
    }

    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
//        if virtualMachine.graphicsDevices.count > 0 {
//            virtualMachine.usbControllers[0].attach(device: <#T##any VZUSBDevice#>, completionHandler: completionNilHandler)
//        }
        print("Guest did stop virtual machine.")
        exit(0)
    }

    func virtualMachine(_ virtualMachine: VZVirtualMachine, networkDevice: VZNetworkDevice, attachmentWasDisconnectedWithError error: Error) {
        print("Network attachment was disconnected with error: \(error.localizedDescription)")
    }
    
    // MARK: USB Discovery

    func deviceAdded(_ device: io_object_t) {
        guard device.locationID != 0 else { return }
        guard device.idProduct != 0 else { return }
        guard device.idVendor != 0 else { return }
        guard device.bDeviceClass != nil && device.bDeviceClass != 9 else { return }

        print("deviceAdded: \(device.name() ?? "<unknown>") (\(device.formatted()))")
        let menuItem: DeviceMenuItem = DeviceMenuItem()
        menuItem.device = device
        menuItem.title = device.name() ?? "<unknown>"
        menuItem.bDeviceClass = device.bDeviceClass
        menuItem.idVendor = device.idVendor
        menuItem.idProduct = device.idProduct
        menuItem.usbVendorName = device.usbVendorName
        menuItem.usbProductName = device.usbProductName
        menuItem.usbSerialNumber = device.usbSerialNumber
        menuItem.usbSpeed = device.usbSpeed
        menuItem.deviceSpeed = device.deviceSpeed
        menuItem.sessionID = device.sessionID
        menuItem.locationID = device.locationID
        menuItem.isEnabled = true
        menuItem.action = #selector(attachDeviceMenuItem(_:))
        DevicesMenu.addItem(menuItem)
    }

    func deviceRemoved(_ device: io_object_t) {
        if device.bDeviceClass != nil && (device.bDeviceClass!) == 9 { return }
        print("deviceRemoved: \(device.name() ?? "<unknown>") (\(device.formatted()))")
        for item in DevicesMenu.items {
            if let menuItem = item as? DeviceMenuItem {
                let menuLocationID: Int? = menuItem.locationID
                let deviceLocationID: Int? = device.locationID
                if menuLocationID != nil && deviceLocationID != nil && menuLocationID! == deviceLocationID! {
                    if menuItem.state == .on {
                        self.dettachDevice(menuItem.device)
                        menuItem.state = .off
                    }
                    DevicesMenu.removeItem(menuItem)
                    return
                }
            }
        }
    }
    
    @objc func attachDeviceMenuItem(_ sender: DeviceMenuItem) {
        // TODO Implement actions
        // See: https://docs.getutm.app/guest-support/macos/#missing-features
        // Actually this feature is not supported by the virtualization framework
//        self.virtualMachine.usbControllers[0].attach(device: sender.device)
        sender.state = .on
        sender.action = #selector(self.dettachDeviceMenuItem(_:))
    }
    
    @objc func dettachDeviceMenuItem(_ sender: DeviceMenuItem) {
        // TODO Implement actions
        // See: https://docs.getutm.app/guest-support/macos/#missing-features
        // Actually this feature is not supported by the virtualization framework
        print("dettachDeviceMenuItem is not implemented")
        sender.state = .off
        sender.action = #selector(self.attachDeviceMenuItem(_:))
    }
    
    @objc func attachDevice(_ device: io_object_t) {
        print("attach device: \(device.name() ?? "<unknown>") (\(device.formatted()))")
    }
        
    @objc func dettachDevice(_ device: io_object_t) {
        print("dettach device: \(device.name() ?? "<unknown>") (\(device.formatted()))")
    }
        
    // MARK: VM Actions Menu Item
    
    @IBAction func startVM(_ sender: Any) {
        print("start vm")
    }
    
    @IBAction func pauseVM(_ sender: Any) {
        print("pause vm")
    }

    @IBAction func resumeVM(_ sender: Any) {
        print("resume vm")
    }

    @IBAction func stopVM(_ sender: Any) {
        print("stop vm")
    }
}

// MARK: Documentation from chatgpt-omini

//In a macOS with apple silicon, I am developing by using Swift, and I want to attach a USB device to a VM which is using the virtualization framework; I can enumerate the devices, but no idea how to accommodate to the protocol that require the virtualization framework, specially the uuid; is this something coming from the real USB device? or something we generate to identify the USB device in the application using the framework?
//
//.
//GPT-4o mini
//To attach a USB device to a virtual machine (VM) using the virtualization framework on macOS with Apple Silicon, you need to understand how to work with the USB device
//
//In a macOS with apple silicon, I am developing by using Swift, and I want to attach a USB device to a VM which is using the virtualization framework; I can enumerate the devices, but no idea how to accommodate to the protocol that require the virtualization framework, specially the uuid; is this something coming from the real USB device? or something we generate to identify the USB device in the application using the framework?
//
//.
//GPT-4o mini
//To attach a USB device to a virtual machine (VM) using the virtualization framework on macOS with Apple Silicon, you need to understand how to work with the USB device's identifiers, particularly the UUID.
//UUID in the Virtualization Framework
//
//Understanding UUID
//
//The UUID (Universally Unique Identifier) used in the virtualization framework is not something that comes from the USB device itself. Instead, it is a unique identifier that you generate within your application to identify the USB device when attaching it to the VM. This UUID is essential for managing the device's lifecycle and ensuring that the VM can correctly reference the device.
//Steps to Attach a USB Device
//
//Enumerate USB Devices: You can use the IOKit framework to enumerate the USB devices connected to your macOS system. This will give you access to the properties of each device, including vendor ID, product ID, and other relevant information.
//Generate a UUID: For each USB device you want to attach, generate a UUID. You can use Swift's UUID() initializer to create a new UUID.
//swift
//Copiar Código
//let usbDeviceUUID = UUID()
//Create a USB Device Configuration: Use the virtualization framework to create a configuration for the USB device. This typically involves creating an instance of VZUSBDeviceConfiguration and setting its properties, including the generated UUID.
//Attach the Device to the VM: Finally, you can attach the USB device to the VM using the VZVirtualMachine instance. You will need to add the USB device configuration to the VM's configuration.
//Example Code Snippet
//
//Here’s a simplified example of how you might implement this in Swift:
//swift
//Copiar Código
//import Virtualization
//import IOKit
//
//func attachUSBDevice(to vm: VZVirtualMachine, usbDevice: IOUSBDevice) {
//    // Generate a UUID for the USB device
//    let usbDeviceUUID = UUID()
//    
//    // Create a USB device configuration
//    let usbDeviceConfiguration = VZUSBDeviceConfiguration(
//        identifier: usbDeviceUUID,
//        vendorID: usbDevice.vendorID,
//        productID: usbDevice.productID
//    )
//    
//    // Attach the USB device to the VM
//    do {
//        try vm.attachUSBDevice(usbDeviceConfiguration)
//        print("USB device attached with UUID: \(usbDeviceUUID)")
//    } catch {
//        print("Failed to attach USB device: \(error)")
//    }
//}
//Summary
//
//The UUID is generated by your application to uniquely identify the USB device within the virtualization framework.
//You need to enumerate the USB devices using IOKit, generate a UUID for each device, create a configuration, and then attach it to the VM.
//If you have any specific questions about the implementation or need further details, feel free to ask!
//
//I would like to take in consideration the BUS where the USB device is connected, so the UUID would be some composition of USB port, vendorID and productID, in that case the UUID would serve to assure that two devices are perfectly identified in the application, and manage the lifecycle of the USB device for the attached VM correctly, or when the device is physically detached to notify to the vm, etc... and keep the list of enumerated USB devices consistent.
//
//.
//GPT-4o mini
//To effectively manage USB devices in your application, especially when considering the bus and port where the USB device is connected, you can indeed create a more structured UUID or identifier that incorporates various attributes of the USB device. This approach will help ensure that each device is uniquely identified and that you can manage its lifecycle accurately.
//Creating a Composite Identifier
//
//Components of the Identifier
//
//You can create a composite identifier that includes:
//Bus Number: The bus number where the USB device is connected.
//Port Number: The specific port on the bus.
//Vendor ID: The unique identifier for the manufacturer of the USB device.
//Product ID: The unique identifier for the specific product.
//Generating the Composite Identifier
//
//You can concatenate these components into a string format that serves as a unique identifier. Here’s how you might implement this in Swift:
//swift
//Copiar Código
//import Foundation
//import IOKit
//
//func generateCompositeIdentifier(busNumber: Int, portNumber: Int, vendorID: Int, productID: Int) -> String {
//    return "\(busNumber)-\(portNumber)-\(vendorID)-\(productID)"
//}
//Example Usage
//
//When enumerating USB devices, you can extract the bus and port information along with the vendor and product IDs, and then generate the composite identifier:
//swift
//Copiar Código
//func attachUSBDevice(to vm: VZVirtualMachine, usbDevice: IOUSBDevice) {
//    // Extract bus and port information
//    let busNumber = usbDevice.busNumber // Assuming you have a way to get this
//    let portNumber = usbDevice.portNumber // Assuming you have a way to get this
//    let vendorID = usbDevice.vendorID
//    let productID = usbDevice.productID
//    
//    // Generate a composite identifier
//    let compositeIdentifier = generateCompositeIdentifier(busNumber: busNumber, portNumber: portNumber, vendorID: vendorID, productID: productID)
//    
//    // Create a USB device configuration
//    let usbDeviceConfiguration = VZUSBDeviceConfiguration(
//        identifier: UUID(uuidString: compositeIdentifier) ?? UUID(),
//        vendorID: vendorID,
//        productID: productID
//    )
//    
//    // Attach the USB device to the VM
//    do {
//        try vm.attachUSBDevice(usbDeviceConfiguration)
//        print("USB device attached with identifier: \(compositeIdentifier)")
//    } catch {
//        print("Failed to attach USB device: \(error)")
//    }
//}
//Managing Device Lifecycle
//
//With this composite identifier, you can effectively manage the lifecycle of the USB device:
//Attach/Detach Notifications: When a device is physically detached, you can check against your list of composite identifiers to determine which device was removed and notify the VM accordingly.
//Consistency: By maintaining a list of enumerated USB devices with their composite identifiers, you can ensure that your application accurately reflects the current state of connected devices.
//Example of Detach Handling
//
//You might implement a method to handle device detachment like this:
//swift
//Copiar Código
//func handleDeviceDetachment(compositeIdentifier: String) {
//    // Logic to find the device in your list and detach it from the VM
//    if let device = findDeviceByIdentifier(compositeIdentifier) {
//        // Notify the VM about the detachment
//        vm.detachUSBDevice(device)
//        print("USB device detached: \(compositeIdentifier)")
//    }
//}
//Summary
//
//Creating a composite identifier that includes bus number, port number, vendor ID, and product ID allows for precise identification of USB devices.
//This identifier can be used to manage the lifecycle of devices effectively, ensuring that your application remains consistent with the physical state of connected USB devices.
//Implementing attach and detach notifications based on this identifier will help maintain the integrity of your VM's USB device management.
//If you have further questions or need more specific examples, feel free to ask!
