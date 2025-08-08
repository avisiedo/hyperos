/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app delegate that sets up and starts the virtual machine.
*/

import Virtualization

let bundleExt = ".bundle"

@main
class VMWindowDelegate: NSObject, NSApplicationDelegate, VZVirtualMachineDelegate {
    private var vmData:VMData
    @IBOutlet weak var mainWindow: VMCardWall!
    @IBOutlet weak var wizard: NSWindow!
    
    @IBOutlet var window: NSWindow!
    
    @IBOutlet weak var virtualMachineView: VZVirtualMachineView!
    
    private var virtualMachine: VZVirtualMachine!

    override init() {
        self.vmData = VMDefaultLinux()
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
        virtualMachineConfiguration.consoleDevices = [createSpiceAgentConsoleDeviceConfiguration()]

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
                }
            })
        }
    }
    
    func launchWizard(_ sender: Any?) {
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
    
    func getBundleName(fromPath path:String) -> String {
        guard path != "" else {
            fatalError("path is an empty string")
        }
        let fileName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        return fileName
    }
    
    func loadDataFromBundle(path:String)-> VMData {
        let fileURL = URL(fileURLWithPath: path + "/machine.json")
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let decodedObject = try decoder.decode(VMData.self, from: data)
            return decodedObject
        } catch {
            fatalError("Error decoding JSON from file: \(error)")
        }
    }
    
    func saveDataToBundle(path:String, vmData:VMData) {
        let fileURL = URL(fileURLWithPath: path + "/machine.json")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(vmData)
            try data.write(to: fileURL)
        } catch {
            fatalError("Error coding JSON to file: \(error)")
        }
    }
    
    func enumerateVMs(atPath path: String, withExtension fileExtension: String) -> [VMData] {
        var vmlist: [VMData] = []
        let fileManager = FileManager.default

        do {
            // Get the contents of the directory
            let items = try fileManager.contentsOfDirectory(atPath: path)

            // Filter the items to find directories with the specified extension
            let directoriesWithExtension = items.filter { item in
                let fullPath = (path as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory)
                return isDirectory.boolValue && item.hasSuffix(".\(fileExtension)")
            }

            // Print the directories found
            for directory in directoriesWithExtension {
                let vmdata = loadDataFromBundle(path: directory)
                vmlist.append(vmdata)
            }
            return vmlist
        } catch {
            print("Error reading directory: \(error.localizedDescription)")
            return []
        }
    }
    
    func prepareWall(_ vms:[VMData]) {
        mainWindow.configure(vmList: vms)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.activate(ignoringOtherApps: true)

        // If "GUI Linux VM.bundle" doesn't exist, the sample app tries to create
        // one and install Linux onto an empty disk image from the ISO image,
        // otherwise, it tries to directly boot from the disk image inside
        // the "GUI Linux VM.bundle".
        var vms:[VMData] = enumerateVMs(atPath: vmPath, withExtension: bundleExt)
        prepareWall(vms)
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
}
