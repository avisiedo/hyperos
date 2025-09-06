# Hyper OS Application

Intent to create a VM manager for macos based on the virtualization framework.

The initial state is coming from the sample code from the documentation at:
https://developer.apple.com/documentation/virtualization/running-gui-linux-in-a-virtual-machine-on-a-mac

## Overview

Intentions:

- Store all the necessary information to instantiate the VM in a bundle.
  - The bundle will have the extension .hyperos
  - The configuration will be stored as a yaml file at the bundle directory.
    - Type of OS => Linux, MacOS, Windows*, BSD*
  - The disks will be stored inside the bundle directory.
  - The snapshots will be stored inside the bundle directory.

> Windows 11 support requires TPM2.0 emulation; design decission here about
> store one keychein per VM at user scope, or one keychain for all the VM
> per user (if there are two users in the systems, they are "isolated", but
> this avoid Shared VMs between the users.

---

> Once TPM2.0 is emulated, the intention is provide by default in the Linux and
> BSD profiles by default, and some initialization to enroll the PK and MOK in
> the TPM for allowing secure boot booting for the OSs.

- Support multiple VMs and manage them.
  - Common directory store all the VM bundles.
- Add a wizard to create new VM.
  - Basic version (We select Fedora or macos initially).
  - Basic 2 version (We select Linux distro + version, and macos version)
    - Add ISO auto-download for the OS selected and version.
    - Verify ISO downloaded for the OS selected and version (verify CHECKSUM file
      by using the public key of the distro and version, check ISO hash with the
      checksum file).
    - ISO, Checksums and public keys for verification are stored at
      ~/Virtual Machines/Cache/<{linux-distroname-version}>/{gpgkey.gpg, ...-CHECKSUM, .iso}
      That 3 files are cached to accelerate new VM creation.
  - Support custom device configurations.
    - Additional virtual disks.
    - Add shared folders between host and guest.
    - Passthrough USB devices.
    - Share CUPS printers => CUPS proxy to communicate betweeen guest and host.
      - The guest agent MUST run in an isolated way (SELinux or AppArmor for Linux,
        jails for BSD systems, gatekeeper for macos, no idea for Windows).
    - Passthrough macos devices (Camera)
    - Share bluetooth devices by using a guest agent which communicate with the
      host by using a proxy.
      - The guest agent MUST run in an isolated way (SELinux or AppArmor for Linux,
        hails for BSD systems, gatekeeper for macos, no idea for Windows).
  - Support Unattended installation.
    - Windows
    - Linux Fedora
      - Classic
      - Silverblue
      - Botoc
    - Debian/Ubuntu
    - Macos
    - BSD
- Add support for macos guest.
  - Install and run.
  - Run in DFU mode (Data Firmware Uploader).
    This would allow to research DFU mode.
  - Run in Recovery mode.
    This would allow to research in Recovery mode.
- Add auto download ISO, and check them.
- Add support for Windows guest (platform requires TPM 2)
- Add support for OpenBSD guest.
- Add support for NetBSD guest.
- Add support for FreeBSD guest.
- Add Serial port for terminal only VMs, useful for automation from the cli.
- Add CLI tool hyperosctl => automation from the cli.
- Add Sandboxes for malware behaviors analysis:
  - Wizard to create sandboxes with CAPE v2 (Linux, Windows, macos)
  - Add automation to analyze a sample, and extract report.
    - Always generate a snapshot from the original VM,
      install and configure the necessary tools, and finally
      execute the sample to analyze it.
- Encrypt VM Disk.
  - Creation of encrypted.
  - Integrate with keychain (store keys encrypted)
- Confidential VM? (can we use confidential computing)
- Network manager
  - Create new virtual networks and topology.
    - Define virtual switches.
    - Add VM interfaces to the right switch.
    - Add DHCP server for automatic configuration.
      - Edit DHCP options for the given network.
--- <!-- Advanced features -->
    - Add domain server.
      - Add Bind Server.
      - Add CA Issuer.
        - Add ACME support.
      - Add DNSSEC support.
      - Add DoT support.
      - Add DoH support.
    - Auto-enroll new VMs on domain.
      - automation per OS for enrolling into the domain server.
      - Automation of hosts policies and configuration.
    - Add monitoring service:
      - Gather cpu usage.
      - Gather memory usage.
      - Gather audit logs.
        - Add advanced monitoring agent.

## Feature Matrix

Feature         | Linux   | macos   | Windows  | BSD |
------------------------------------------------------
TPM2.0          | No      | No      | No       | No  |
Download ISO    | No      | No      | No       | No  |
Verify ISO      | No      | No      | No       | No  |

Share Folder    | No      | No      | No       | No  |
Share USB       | No      | No      | No       | No  |
Share Cammera   | No      | No      | No       | No  |
Share Bluetooth | No      | No      | No       | No  |

Network Manager | NO
 Define Virtual Switches
 Attach interfaces to switches
 Add DHCP server
  Edit DHCP server options
 Add domain server
  Add Bind Server
  Add CA Issuer
   Add ACME support
  Add DNSSEC support
  Add DoT support
  Add DoH support
 Auto-enroll new VMs on domain.
  Automation per OS for enrolling into the domain server.
  Automation of hosts policies and configuration.
 Add monitoring services:
  Gather cpu usage
  Gather memory usage
  Gather audit logs
   Add advanced monitoring agent




---

> "One ring to govern every host".

---

This sample code project demonstrates how to install and run GUI Linux virtual machines (VMs) on a Mac.

The Xcode project includes a single target, `GUILinuxVirtualMachineSampleApp`, which is a macOS app that installs a Linux distribution from an ISO image into a VM, and subsequently runs the installed Linux VM.

[class_VZVirtualMachineConfiguration]:https://developer.apple.com/documentation/virtualization/vzvirtualmachineconfiguration
[class_VZLinuxBootLoader]:https://developer.apple.com/documentation/virtualization/vzlinuxbootloader
[class_VZVirtualMachine]:https://developer.apple.com/documentation/virtualization/vzvirtualmachine
[property_bootLoader]:https://developer.apple.com/documentation/virtualization/vzvirtualmachineconfiguration/3656716-bootloader
[method_start]:https://developer.apple.com/documentation/virtualization/vzvirtualmachine/3656826-start
[method_guestDidStop]:https://developer.apple.com/documentation/virtualization/vzvirtualmachinedelegate/3656730-guestdidstop

## Download a Linux installation image 

Before you run the sample program, you need to download an ISO installation image from a Linux distribution website. Some common Linux distributions include:

- [Debian](https://www.debian.org/distrib/)
- [Fedora](https://getfedora.org/en/workstation/download/)
- [Ubuntu](https://ubuntu.com/download/desktop)


- Important: The Virtualization framework can run Linux VMs on a Mac with Apple silicon, and on an Intel-based Mac. The Linux ISO image you download must support the CPU architecture of your Mac. For a Mac with Apple silicon, download a Linux ISO image for ARM, which is usually indicated by `aarch64` or `arm64` in the image filename. For an Intel-based Mac, download a Linux ISO image for Intel-compatible CPUs, which is usually indicated by `x86_64` or `amd64` in the image filename.

- Note: If you need to run Intel Linux binaries in ARM Linux on a Mac with Apple silicon, the Virtualization framework supports this capability using the Rosetta translation environment. For more information, see [Running Intel Binaries in Linux VMs with Rosetta](https://developer.apple.com/documentation/virtualization/running_intel_binaries_in_linux_vms_with_rosetta).


## Configure the sample code project

- Note: The default deployment target is macOS14, if you need to build for a different version of macOS you’ll need to change the deployment target as appropriate.

1. Launch Xcode and open `GUILinuxVirtualMachineSampleApp.xcodeproj`.

2. Navigate to the Signing & Capabilities panel and select your team ID.

3. Build and run GUILinuxVirtualMachineSampleApp. The sample app starts the VM and configures a graphical view that you interact with. The Linux VM continues running until you shut it down from the guest OS, or when you quit the app.

    When you run the app for the first time, it displays a file picker so you can choose the Linux installation ISO image to use for installing your Linux VM. Navigate to the ISO image that you downloaded, select the file, and click Open. The VM boots into the OS installer, and the installer's user interface appears in the app's window. Follow the installation instructions. When the installation finishes, the Linux VM is ready to use.

     As part of the installation process, the Virtualization framework creates a `GUI Linux VM.bundle` package in your home directory. The sample app only supports running one VM at a time, however, the Virtualization framework supports running multiple VMs simultaneously. Running multiple VMs requires an app to manage the execution and artifacts of each individual VM.
    
    The contents of the bundle represent the state of the Linux guest, and contain the following:

    * `Disk.img` — The main disk image of the installed Linux OS.
    * `MachineIdentifier` — The data representation of the `VZGenericMachineIdentifier` object.
    * `NVRAM` — The EFI variable store.

    Subsequent launches of GUILinuxVirtualMachineSampleApp run the installed Linux VM. To reinstall the VM, delete the `GUI Linux VM.bundle` package and run the app again.


## Install GUI Linux from an ISO image

The sample app configures a `VZDiskImageStorageDeviceAttachment` object with the downloaded ISO image attached, and creates a `VZUSBMassStorageDeviceConfiguration` with it to emulate a USB thumb drive that's plugged in to the VM.

``` swift
private func createUSBMassStorageDeviceConfiguration() -> VZUSBMassStorageDeviceConfiguration {
    guard let intallerDiskAttachment = try? VZDiskImageStorageDeviceAttachment(url: installerISOPath!, readOnly: true) else {
        fatalError("Failed to create installer's disk attachment.")
    }

    return VZUSBMassStorageDeviceConfiguration(attachment: intallerDiskAttachment)
}
```


## Set up the VM

The sample app uses a [`VZVirtualMachineConfiguration`][class_VZVirtualMachineConfiguration] object to configure the basic characteristics of the VM, such as the CPU count, memory size, various device configurations, and a `VZEFIBootloader` to load the Linux operating system into the VM.

``` swift
let virtualMachineConfiguration = VZVirtualMachineConfiguration()

virtualMachineConfiguration.cpuCount = computeCPUCount()
virtualMachineConfiguration.memorySize = computeMemorySize()

let platform = VZGenericPlatformConfiguration()
let bootloader = VZEFIBootLoader()
let disksArray = NSMutableArray()

if needsInstall {
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
virtualMachine = VZVirtualMachine(configuration: virtualMachineConfiguration)
```

## Enable copy-and-paste support between the host and the guest

In macOS 13 and later, the Virtualization framework supports copy-and-paste of text and images between the Mac host and Linux guests through the SPICE agent clipboard-sharing capability. The example below shows the steps for configuring `VZVirtioConsoleDeviceConfiguration` and `VZSpiceAgentPortAttachment` to enable this capability:
``` swift
private func createSpiceAgentConsoleDeviceConfiguration() -> VZVirtioConsoleDeviceConfiguration {
    let consoleDevice = VZVirtioConsoleDeviceConfiguration()

    let spiceAgentPort = VZVirtioConsolePortConfiguration()
    spiceAgentPort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
    spiceAgentPort.attachment = VZSpiceAgentPortAttachment()
    consoleDevice.ports[0] = spiceAgentPort

    return consoleDevice
}
```

- Important: To use the copy-and-paste capability in Linux, the user needs to install the spice-vdagent package, which is available through most Linux package managers. Developers need to communicate this requirement to users of their apps.


## Start the VM

After building the configuration data for the VM, the sample app uses the `VZVirtualMachine` object to start the execution of the Linux guest operating system.

Before calling the VM's [`start`][method_start] method, the sample app configures a delegate object to receive messages about the state of the virtual machine. When the Linux operating system shuts down, the VM calls the delegate's [`guestDidStop`][method_guestDidStop] method. In response, the delegate method prints a message and exits the sample.

``` swift
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
```

The app sets the display to automatically resize when the window size changes.

## References

- [Running GUI Linux in a VM on a mac](https://developer.apple.com/documentation/virtualization/running-gui-linux-in-a-virtual-machine-on-a-mac).
- [Demostrate Hypervisor.Framework usage in Apple Silicon](https://gist.github.com/imbushuo/51b09e61ecd7b7ac063853ad65cedf34).

