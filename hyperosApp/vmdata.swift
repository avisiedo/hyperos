//
//  vmdata.swift
//  hyperosApp
//
//  Created by Alejandro Visiedo on 7/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import Foundation

enum VMType: String, Codable {
    case Windows
    case Linux
    case MacOS
    case BSD
}

struct VMData: Codable {
    let vmType:VMType
    var bundleName:String
    var machineIdentifierPath:String
    
    var cpus:Int
    var memory:UInt64
    var mainDiskSize:Int64
    var installerISOPath: URL?
    var installerISOHash: String

    var diskImagePath: String
    var efiVariableStorePath: String
    var diskImages:[String]
    var needsInstall:Bool = true
    
    init() {
        self.init(vmType:.Linux)
    }
    
    init(vmType:VMType) {
        self.vmType = vmType
        self.bundleName = "New VM"
        self.machineIdentifierPath = "MachinieIdentifier"
        
        self.cpus = 2
        self.memory = 4*1024*1024*1024
        self.mainDiskSize = 10*1024*1024*1024
        // TODO Remove hardcoded values
        self.installerISOPath = NSURL(string: "https://download.fedoraproject.org/pub/fedora/linux/releases/42/Silverblue/aarch64/iso/Fedora-Silverblue-ostree-aarch64-42-1.1.iso") as URL?
        self.installerISOHash = "a243a9f3920ba2a6fcb0cf99539c9862a90abbd590cf36e35fdf658a7ff7e0f2"
        self.diskImagePath = "Disk.img"
        self.efiVariableStorePath = "NVRAM"
        self.diskImages = []
        self.needsInstall = true
    }
    
    init(from decoder: any Decoder) throws {
        // Create a container for the properties
        let container = try decoder.container(keyedBy: CodingKeys.self)
                
        // Decode the properties using the container
        self.vmType = try container.decode(VMType.self, forKey: .vmType)
        self.bundleName = try container.decode(String.self, forKey: .bundleName)
        self.machineIdentifierPath = try container.decode(String.self, forKey: .machineIdentifierPath)
        self.cpus = try container.decode(Int.self, forKey: .cpus)
        self.memory = try container.decode(UInt64.self, forKey: .memory)
        self.mainDiskSize = try container.decode(Int64.self, forKey: .mainDiskSize)
        self.installerISOPath = try container.decodeIfPresent(URL.self, forKey: .installerISOPath)
        self.installerISOHash = try container.decode(String.self, forKey: .installerISOHash)
        self.diskImagePath = try container.decode(String.self, forKey: .diskImagePath)
        self.efiVariableStorePath = try container.decode(String.self, forKey: .efiVariableStorePath)
        self.diskImages = try container.decode([String].self, forKey: .diskImages)
        self.needsInstall = try container.decodeIfPresent(Bool.self, forKey: .needsInstall) ?? true
    }
    func encode(to encoder: any Encoder) throws {
        guard let jsonEncoder = encoder as? JSONEncoder else {
            fatalError("Provided encoder is not a JSONEncoder.")
        }
        do {
            let jsonData = try jsonEncoder.encode(self)
        } catch {
            fatalError("encoding json data failed")
        }
    }
    enum CodingKeys: String, CodingKey {
        case vmType
        case bundleName
        case machineIdentifierPath
        case cpus
        case memory
        case mainDiskSize
        case installerISOPath
        case installerISOHash
        case diskImagePath
        case efiVariableStorePath
        case diskImages
        case needsInstall
    }
}
