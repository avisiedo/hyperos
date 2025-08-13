/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app delegate that sets up and starts the virtual machine.
*/

import Virtualization


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
    
    @IBOutlet weak var vmStateStartMenuItem: NSMenuItem!
    @IBOutlet weak var vmStateStopMenuItem: NSMenuItem!
    @IBOutlet weak var vmStatePauseMenuItem: NSMenuItem!
    @IBOutlet weak var vmStateResumeMenuItem: NSMenuItem!
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

    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        print("Guest did stop virtual machine.")
        exit(0)
    }

    func virtualMachine(_ virtualMachine: VZVirtualMachine, networkDevice: VZNetworkDevice, attachmentWasDisconnectedWithError error: Error) {
        print("Network attachment was disconnected with error: \(error.localizedDescription)")
    }
    
    // MARK: USB Discovery
    
    func deviceAdded(_ device: io_object_t) {
        if device.bDeviceClass != nil && (device.bDeviceClass!) == 9 { return }
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
        print("attachDeviceMenuItem is not implemented")
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
//        self.virtualMachine.usbControllers[0].attach(device)
    }
        
    @objc func dettachDevice(_ device: io_object_t) {
        print("dettach device: \(device.name() ?? "<unknown>") (\(device.formatted()))")
    }
        
    // MARK: VM Actions Menu Item + VZVirtualMachineDelegate

//    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
//        self.vmStateStopMenuItem.state = .off
//        self.vmStateStartMenuItem.state = .on
//        self.vmStateResumeMenuItem.state = .off
//        self.vmStatePauseMenuItem.state = .on
//    }

    @IBAction func startVM(_ sender: Any) {
        switch self.virtualMachine.state {
            case .running:
                return
            case .paused:
                print("resuming vm")
                self.resumeVM(self)
                self.vmStateStopMenuItem.state = .on
                self.vmStateStartMenuItem.state = .off
                self.vmStateResumeMenuItem.state = .off
                self.vmStatePauseMenuItem.state = .on
                return
            case .stopped:
                print("starting vm")
                self.startVM(self)
                self.vmStateStopMenuItem.state = .on
                self.vmStateStartMenuItem.state = .off
                self.vmStateResumeMenuItem.state = .off
                self.vmStatePauseMenuItem.state = .on
                return
            case .error:
                return
            @unknown default:
                return
        }
    }
    
    @IBAction func pauseVM(_ sender: Any) {
        switch self.virtualMachine.state {
            case .running:
                print("pausing vm")
                self.pauseVM(self)
                self.vmStateStopMenuItem.state = .off
                self.vmStateStartMenuItem.state = .off
                self.vmStateResumeMenuItem.state = .on
                self.vmStatePauseMenuItem.state = .off
                return
            case .paused:
                return
            case .stopped:
                return
            case .error:
                return
            default:
                return
        }
    }

    @IBAction func resumeVM(_ sender: Any) {
        switch self.virtualMachine.state {
            case .running:
                return
            case .paused:
                print("resuming vm")
                self.resumeVM(self)
                self.vmStateStopMenuItem.state = .on
                self.vmStateStartMenuItem.state = .off
                self.vmStateResumeMenuItem.state = .off
                self.vmStatePauseMenuItem.state = .on
                return
            case .stopped:
                return
            case .error:
                return
            @unknown default:
                return
        }
    }

    @IBAction func stopVM(_ sender: Any) {
        switch self.virtualMachine.state {
            case .running:
                print("stopping vm")
                self.resumeVM(self)
                self.vmStateStopMenuItem.state = .off
                self.vmStateStartMenuItem.state = .on
                self.vmStateResumeMenuItem.state = .off
                self.vmStatePauseMenuItem.state = .off
                return
            case .paused:
                return
            case .stopped:
                return
            case .error:
                return
            @unknown default:
                return
        }
    }
}
