//
//  ButtonStyles.swift
//  short_diary
//

import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.paper)
            .background(configuration.isPressed ? Color.ink.opacity(0.82) : Color.ink, in: RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct ReactionButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 12)
            .foregroundStyle(isSelected ? Color.paper : Color.ink)
               .background(isSelected ? Color.moss : Color.paper.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.moss : AppTheme.line)
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
