//
//  device_menu_item.swift
//  hyperosApp
//
//  Created by Alejandro Visiedo on 13/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//
import Foundation
import IOKit
import IOUSBHost
import AppKit

class DeviceMenuItem: NSMenuItem {
    var device: io_object_t

    var usbSpeed: Int?
    var deviceSpeed: Int?
    var usbVendorName: String?
    var usbProductName: String?
    var usbSerialNumber: String?
    var idVendor: Int?
    var idProduct: Int?

    var bDeviceClass: Int?
    var locationID: Int?
    var sessionID: Int?

    override init(title: String, action: Selector?, keyEquivalent: String = "") {
        self.device = IO_OBJECT_NULL
        super.init(title: title, action: action, keyEquivalent: keyEquivalent)
    }

    required init(coder: NSCoder) {
        self.device = IO_OBJECT_NULL
        super.init(coder: coder)
    }
}
