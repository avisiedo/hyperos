//
//  cardView.swift
//  hyperosApp
//
//  Created by Alejandro Visiedo on 7/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//
import SwiftUI
import Virtualization

// Represent the base systems
enum BasePlatform: String {
    case macos
    case linux
//    case windows
//    case bsd
}

// Represent specific systems for macos; each type associated to this
// knows how to download the system, verify it, and the location to the
// image to use for installing.
enum SpecificPlatformMacos: String {
//    case macos10
//    case macos11
//    case macos12
//    case macos13
//    case macos14
    case macos15
//    case macos26
}

// Represent specific systems for macos; each type associated to this
// knows how to download the system, verify it, and the location to the
// image to use for installation. But generic which is insecure
// and just download the image, but does not verify; it is recommended
// to avoid this one, but could be useful in some scenarios
enum SpecificPlatformLinux {
//    case generic
    case silverblue42
    case fedora42
    
//    case ubuntu2404
    
//    case debian11
    
}

//enum SpecificPlatformBSD {
//    case openbsd6_2
//    case freebsd5_3
//    case netbsd6_2
//}

// Protocol that represent the basic
protocol DownloadableOS {
    // Download the artifacts into the target directory
    // This use to be the ISO image, but also the .sha256sum file
    // or the public key to verify the .sha256sum is not tempered.
    // The actions should create a directory in target for the
    // specific object (silverblue42), deploy necessary artifacts,
    // and even uncompress the necessary files to provide the
    // image file required by ISO
    func Download(target:URL)
    // Check .sha256sum file is not tempered
    // Check .sha256sum hashes for the ISO file
    func Verify() -> Bool
    // Return the absolute path to the ISO image
    func ISO() -> String
}

protocol virtualPlataform {
    func name() -> String
}

protocol virtualDevice {
    // String with the device class name
    // - boot
    // - disks
    // - networks
    // - cpus
    // - memory
    func className() -> String
    // Device name showed to the user
    func name() -> String
    // Icon that represent the device type
    func icon() -> Image
}

struct linuxBootLoader {
    var kernelURL: URL
    var initialRamdiskURL: URL?
    // Example
    // ["console=hvc0", "rd.break=initqueue"]
    var kernelArgs: [String]
}

struct macosBootLoader {
    // Path to the .ipsw file with the macos image.
    var imageURL: URL
}

struct consoleConfiguration {
}

struct VM {
    var cpus: Int
    var memory: Int
    var linuxBootLoader: linuxBootLoader
    var console: consoleConfiguration
}

struct VMListItem: View {
    var title: String
    var description: String
    var body: some View {
        HStack {
            Image("UnknownVM")
                .frame(width: 160, height: 120)
                .scaledToFit()
        }
        VStack {
            Text(title)
                .bold()
            Text(description)
        }
    }
}

protocol VMListDelegate {
    func createVM()
}

struct VMList: View {
    @State var vms: [VM] = []
    var delegate: VMListDelegate?
    var body: some View {
        VStack {
            Button("Create VM", systemImage: "plus", action: self.delegate?.createVM ?? {})
            Divider()
            List {
                VMListItem(title: "Create . . .", description: "Created by Unknown User")
            }
        }
    }
}

struct VMCardView2: View {
    var title: String = "My Unknown VM"
    var body: some View {
        VStack {
            Image("UnknownVM")
                .resizable()
                .scaledToFit()
            Text(title)
                .font(.title)
        }
    }
}

struct VMNewCardVM2: View {
    var title: String = "Create VM . . ."
    var body: some View {
        VStack {
            Image("UnknownVM")
                .resizable()
                .scaledToFit()
            Text(title)
                .font(.title)
        }
    }
}

struct WallVM: View {
    var body: some View {
        
    }
}

class VMCardView: NSBox {
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var name: NSTextField!
    func configure(_ image:NSImage?, title:String) {
        imageView.image = image
        name.stringValue = title
    }
}


class VMCardNewVM: NSBox {
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var label: NSTextField!
    var body: some View {
        Text("Hello SwiftUI!")
    }
}

class VMCardWall: NSWindow {
    @IBOutlet weak var wallView: NSGridView!
    func configure(vmList data:[VMData]) {
        let cols = 4
//        let rows = (data.count+1+(cols-1)) / cols
        let view: VMCardNewVM! = VMCardNewVM()
        var row:[NSBox] = []
        row.append(view)
        var idx = 1
        for item in data {
            let vmcard = VMCardView()
            vmcard.configure(nil, title: item.bundleName)
            row.append(vmcard)
            if (1+idx) % cols == 0 {
                wallView.addRow(with: row)
                row = []
            }
            idx = idx + 1
        }
        if row != [] {
            wallView.addRow(with: row)
            row = []
        }
    }
}

#Preview {
    VMListItem(
        title:"Create VM . . .",
        description:""
    )
}

#Preview {
    VMCardView2()
}

#Preview {
    VMNewCardVM2()
}
