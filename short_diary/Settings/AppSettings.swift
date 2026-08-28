//
//  AppSettings.swift
//  short_diary
//

import Foundation
import SwiftUI

enum AppSettings {
    static let bottleTextSizeKey = "bottleTextSize"
    static let bottleColorModeKey = "bottleColorMode"
    static let defaultBottleColorKey = "defaultBottleColor"
}

enum BottleTextSize: String, CaseIterable, Identifiable {
    case small
    case standard
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: "小"
        case .standard: "標準"
        case .large: "大"
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: .small
        case .standard: .large
        case .large: .xxLarge
        }
    }

    static func value(for rawValue: String) -> BottleTextSize {
        BottleTextSize(rawValue: rawValue) ?? .standard
    }
}

enum BottleColorMode: String, CaseIterable, Identifiable {
    case chooseEachTime
    case useDefault

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chooseEachTime: "毎回選ぶ"
        case .useDefault: "同じ色"
        }
    }

    static func value(for rawValue: String) -> BottleColorMode {
        BottleColorMode(rawValue: rawValue) ?? .chooseEachTime
    }
}
