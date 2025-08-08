//
//  cardView.swift
//  hyperosApp
//
//  Created by Alejandro Visiedo on 7/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//
import Cocoa

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
