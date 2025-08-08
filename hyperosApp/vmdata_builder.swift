//
//  vmdata_builder.swift
//  hyperosApp
//
//  Created by Alejandro Visiedo on 7/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import Foundation
import Virtualization

let vmPath = NSHomeDirectory() + "/VirtualMachines"

func generateBundleName() -> String {
//    while true {
//        let uuidString = UUID().uuidString
//        let bundleName = "vm-" + uuidString
//        if FileManager.default.fileExists(atPath: vmPath + "/" + bundleName + ".bundle") {
//            continue
//        }
//        return bundleName
//    }
    return "GUI Linux VM"
}

func VMDefaultWindows() -> VMData {
    // https://learn.microsoft.com/en-us/windows/whats-new/windows-11-requirements
    let minCPU = 2
    let minMemory:UInt64 = 4*1014*1024*1024
    let minDiskSize = Int64(64*1024*1024*1024)
    var data:VMData
    data = VMData(vmType:.Windows)
    data.bundleName = generateBundleName()
    data.machineIdentifierPath = "MachineIdentifier"
    data.cpus = minCPU
    data.memory = minMemory
    data.mainDiskSize = minDiskSize
    data.installerISOPath =  URL(filePath:"https://software.download.prss.microsoft.com/dbazure/Win11_24H2_Spanish_Arm64.iso?t=636d025b-94f3-47e0-89ee-d3c96d9946ac&P1=1754645474&P2=601&P3=2&P4=qgPwZ%2bVF4lWPIB%2frZSDeOU1Y94YSbPNnKsMnfWmAwIyDq2Yo19XtP%2f34nkWSYscefM7JON8X0bWm%2biT%2f%2by%2f3gZiMK73bqB%2fFmDvnC3PMk7d9HJWsVI3JWrzX3k3T7A8sC4SNX%2b7jXQqD4AAGU3MwUiRTEv5wOyjWCiyw493MMN79BoLwpWDDqTe3OCZnvilcUW7BBcWkMjSeL23OYYn6wUJcFaake00JHpM93OJj5CK7BLoZIv6jyp7tEP%2fGUgLf7G4SiOwQUXMIexh9TuwALXKxz0qFOSKo56eatg9NMnQouJyN0je%2bn5V3e9MjstczctcVydjG7IFPcElVT5UgNA%3d%3d")
    data.installerISOHash = "2ffb5126acb6a66198b4f7f5f3dd094df763367df489512a14aba9ce3d4b0e0b"
    data.diskImagePath = "Disk.img"
    data.efiVariableStorePath = "NVRAM"
    data.diskImages = []
    data.needsInstall = true
    return data
}

// MARK: Default Linux

func VMDefaultLinux() -> VMData {
    // https://docs.fedoraproject.org/en-US/fedora/latest/release-notes/hardware_overview/
    let minCPU = 2
    let minMemory = UInt64(2*1014*1024*1024)
    let minDiskSize = Int64(15*1024*1024*1024)
    var data: VMData
    data = VMData(vmType:.Linux)
    data.bundleName = generateBundleName()
    data.machineIdentifierPath = "MachineIdentifier"
    data.cpus = minCPU
    data.memory = minMemory
    data.mainDiskSize = minDiskSize
    data.installerISOPath = URL(filePath: "https://download.fedoraproject.org/pub/fedora/linux/releases/42/Silverblue/aarch64/iso/Fedora-Silverblue-ostree-aarch64-42-1.1.iso")
    data.installerISOHash = "a243a9f3920ba2a6fcb0cf99539c9862a90abbd590cf36e35fdf658a7ff7e0f2"
    data.diskImagePath = "Disk.img"
    data.efiVariableStorePath = "NVRAM"
    data.diskImages = []
    data.needsInstall = true
    return data
}

// MARK: Default MacOS

func VMDefaultMacOS() -> VMData {
    // https://developer.apple.com/documentation/virtualization/vzvirtualmachineconfiguration
    // import Virtualization
    // VZVirtualMachineConfiguration.minimumAllowedMemorySize
    // VZVirtualMachineConfiguration.minimumAllowedCPUCount
    let minCPU = VZVirtualMachineConfiguration.minimumAllowedCPUCount
    let minMemory = UInt64(VZVirtualMachineConfiguration.minimumAllowedMemorySize * 1024)
    let minDiskSize = Int64()
    var data = VMData(vmType:.MacOS)
    data.bundleName = generateBundleName()
    data.machineIdentifierPath = "MachineIdentifier"
    data.cpus = minCPU
    data.memory = minMemory
    data.mainDiskSize = minDiskSize
    data.installerISOPath = URL(filePath: "https://updates.cdn-apple.com/2025SummerFCS/fullrestores/082-08674/51294E4D-A273-44BE-A280-A69FC347FB87/UniversalMac_15.6_24G84_Restore.ipsw")
    data.installerISOHash = "7dd9ab8dba1e088c297934f7d14a0df144f7ec91"
    data.diskImagePath = "Disk.img"
    data.efiVariableStorePath = "NVRAM"
    data.diskImages = []
    data.needsInstall = true
    return data
}

// MARK: Default BSD

func VMDefaultBSD() -> VMData {
    //
    let minCPU = VZVirtualMachineConfiguration.minimumAllowedCPUCount
    let minMemory = UInt64(VZVirtualMachineConfiguration.minimumAllowedMemorySize * 1024)
    let minDiskSize = Int64(10*1024*1024*1024)
    var data = VMData(vmType:.BSD)
    data.bundleName = generateBundleName()
    data.machineIdentifierPath = "MachineIdentifier"
    data.cpus = minCPU
    data.memory = minMemory
    data.mainDiskSize = minDiskSize
    // https://www.openbsd.org/faq/faq4.html#Download
    data.installerISOPath = URL(filePath: "https://ftp.openbsd.org/pub/OpenBSD/7.7/arm64/install77.iso")
    data.installerISOHash = ""
    data.diskImagePath = "Disk.img"
    data.efiVariableStorePath = "NVRAM"
    data.diskImages = []
    data.needsInstall = true
    return data
}
