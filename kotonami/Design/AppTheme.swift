//
//  AppTheme.swift
//  kotonami
//

import SwiftUI

enum AppTheme {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.96, green: 0.94, blue: 0.90),
            Color(red: 0.91, green: 0.94, blue: 0.92)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let mist = Color(red: 0.84, green: 0.89, blue: 0.84)
    static let line = Color(red: 0.76, green: 0.74, blue: 0.68)
}

extension Color {
    static let ink = Color(red: 0.13, green: 0.14, blue: 0.13)
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let cedar = Color(red: 0.52, green: 0.28, blue: 0.19)
    static let moss = Color(red: 0.28, green: 0.43, blue: 0.31)
}
