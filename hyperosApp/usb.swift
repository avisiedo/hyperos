//
//  usb.swift
//  hyperosApp
//
//  Created by Alejandro Visiedo on 12/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//

// see: https://stackoverflow.com/questions/52933325/detect-usb-devices-with-swift-4-on-macos
import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib
import Virtualization

public protocol USBWatcherDelegate: AnyObject {
    /// Called on the main thread when a device is connected.
    func deviceAdded(_ device: io_object_t)

    /// Called on the main thread when a device is disconnected.
   func deviceRemoved(_ device: io_object_t)
}

/// An object which observes USB devices added and removed from the system.
/// Abstracts away most of the ugliness of IOKit APIs.
public class USBWatcher {
    private weak var delegate: USBWatcherDelegate?
    private let notificationPort = IONotificationPortCreate(kIOMainPortDefault)
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0



    public init(delegate: USBWatcherDelegate) {
        self.delegate = delegate

        func handleNotification(instance: UnsafeMutableRawPointer?, _ iterator: io_iterator_t) {
            let watcher = Unmanaged<USBWatcher>.fromOpaque(instance!).takeUnretainedValue()
            let handler: ((io_iterator_t) -> Void)?
            switch iterator {
                case watcher.addedIterator: handler = watcher.delegate?.deviceAdded
                case watcher.removedIterator: handler = watcher.delegate?.deviceRemoved
                default: assertionFailure("received unexpected IOIterator"); return
            }
            while case let device = IOIteratorNext(iterator), device != IO_OBJECT_NULL {
                handler?(device)
                IOObjectRelease(device)
            }
        }

        let query = IOServiceMatching(kIOUSBDeviceClassName)
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()

        // Watch for connected devices.
        IOServiceAddMatchingNotification(
            notificationPort, kIOMatchedNotification, query,
            handleNotification, opaqueSelf, &addedIterator)

        handleNotification(instance: opaqueSelf, addedIterator)

        // Watch for disconnected devices.
        IOServiceAddMatchingNotification(
            notificationPort, kIOTerminatedNotification, query,
            handleNotification, opaqueSelf, &removedIterator)

        handleNotification(instance: opaqueSelf, removedIterator)

        // Add the notification to the main run loop to receive future updates.
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            IONotificationPortGetRunLoopSource(notificationPort).takeUnretainedValue(),
            .commonModes)
    }

    deinit {
        IOObjectRelease(addedIterator)
        IOObjectRelease(removedIterator)
        IONotificationPortDestroy(notificationPort)
    }
}

extension io_object_t {
    /// - Returns: The device's name.
    func name() -> String? {
        let buf = UnsafeMutablePointer<io_name_t>.allocate(capacity: 1)
        defer { buf.deallocate() }
        return buf.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<io_name_t>.size) {
            if IORegistryEntryGetName(self, $0) == KERN_SUCCESS {
                return String(cString: $0)
            }
            return nil
        }
    }
    
    func getProperty<T>(key: String) -> T? {
        let keyAsCFString = key as CFString
        let value = IORegistryEntryCreateCFProperty(self, keyAsCFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        return value as? T
    }
    
    var usbVendorName: String? {
        return getProperty(key: "USB Vendor Name")
    }
    
    var usbProductName: String? {
        return getProperty(key: "USB Product Name")
    }
    
    var usbSerialNumber: String? {
        return getProperty(key: "USB Serial Number")
    }
    
    var idVendor: Int? {
        return getProperty(key: "idVendor")
    }
    
    var idProduct: Int? {
        return getProperty(key: "idProduct")
    }
    
    // bDeviceClass is 9 for HUB controller.
    var bDeviceClass: Int? {
        return getProperty(key: "bDeviceClass")
    }

    // MARK: Properties for USB type indicator

    // USBSpeed represents the speed of the USB bus where the device is connected.
    var usbSpeed: Int? {
        return getProperty(key: "USBSpeed")
    }

    // DeviceSpeec represents the maximimum available of the device, that will not be higher
    // than the device bus speed.
    var deviceSpeed: Int? {
        return getProperty(key: "Device Speed")
    }

    // MARK: Identification

    var sessionID: Int? {
        return getProperty(key: "sessionID")
    }
    var locationID: Int? {
        return getProperty(key: "locationID")
    }
}

class usbDelegate: USBWatcherDelegate {
    private var usbWatcher: USBWatcher!
    init(_ delegate:USBWatcherDelegate!) {
        usbWatcher = USBWatcher(delegate: delegate)
        var notificationPort: IONotificationPortRef?
        var iterator: io_iterator_t = 0

        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)

        let addedCallback: IOServiceMatchingCallback = { (refcon, iterator) in
            print("addedCallback")
        }

        let removedCallback: IOServiceMatchingCallback = { (refcon, iterator) in
            print("removedCallback")
        }

        IOServiceAddMatchingNotification(notificationPort!, kIOGeneralInterest, matchingDict, addedCallback, nil, &iterator)
        IOServiceAddMatchingNotification(notificationPort!, kIOGeneralInterest, matchingDict, removedCallback, nil, &iterator)
    }

    func deviceAdded(_ device: io_object_t) {
        let unknown: String = "<unknown>"
        print("device added: \(device.name() ?? unknown) (locationID=\(device.locationID ?? -1); sessionID=\(device.sessionID ?? -1)")
    }

    func deviceRemoved(_ device: io_object_t) {
        print("device removed: \(device.name() ?? "<unknown>") (\(device.formatted()))")
    }
}

@available(macOS 15.0, *)
class usbDevice: NSObject, VZUSBDevice {
    var usbController: VZUSBController?
    var uuid: UUID
    init(attachedTo controller:VZUSBController, uuid: UUID) {
        self.usbController = controller
        self.uuid = uuid
    }
}

@available(macOS 15.0, *)
class usbDeviceConfiguration: NSObject, VZUSBDeviceConfiguration {
    var uuid: UUID
    init(_ uuid:UUID) {
        self.uuid = uuid
    }
}


