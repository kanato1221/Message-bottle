//
//  BottleColorStyle.swift
//  kotonami
//

import SwiftUI

extension BottleColor {
    var title: String {
        switch self {
        case .seaGreen: "海緑"
        case .amber: "琥珀"
        case .skyBlue: "空色"
        case .smoke: "薄墨"
        case .rose: "夕紅"
        }
    }

    var mainColor: Color {
        switch self {
        case .seaGreen: Color.moss
        case .amber: Color(red: 0.71, green: 0.50, blue: 0.25)
        case .skyBlue: Color(red: 0.34, green: 0.57, blue: 0.72)
        case .smoke: Color(red: 0.43, green: 0.48, blue: 0.49)
        case .rose: Color(red: 0.70, green: 0.38, blue: 0.36)
        }
    }

    var highlightColor: Color {
        switch self {
        case .seaGreen: Color(red: 0.68, green: 0.83, blue: 0.78)
        case .amber: Color(red: 0.92, green: 0.74, blue: 0.44)
        case .skyBlue: Color(red: 0.68, green: 0.83, blue: 0.90)
        case .smoke: Color(red: 0.78, green: 0.80, blue: 0.78)
        case .rose: Color(red: 0.88, green: 0.62, blue: 0.58)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [
                mainColor.opacity(0.72),
                highlightColor.opacity(0.48)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

