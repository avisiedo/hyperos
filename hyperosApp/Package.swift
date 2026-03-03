//
//  Package.swift
//  hyperosApp
//
//  Created by Alejandro Visiedo on 1/3/26.
//  Copyright © 2026
//
// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "hyperosApp",
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "hyperosApp"
        ),
    ]
)
