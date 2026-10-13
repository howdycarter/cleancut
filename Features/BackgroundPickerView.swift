//
//  BackgroundPickerView.swift
//  CleanCut
//
import SwiftUI

struct BackgroundPickerView: View {
    var selected: BackgroundType
    var onSelect: (BackgroundType) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(BackgroundType.allCases, id: \.self) { type in
                    BackgroundChip(type: type, isSelected: selected == type) {
                        onSelect(type)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct BackgroundChip: View {
    var type: BackgroundType
    var isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(chipColor)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                Text(type.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color(cleanCutHex: "#2C7BE5").opacity(0.4) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? Color(cleanCutHex: "#2C7BE5") : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var chipColor: Color {
        switch type {
        case .transparent: return Color.clear
        case .white: return Color.white
        case .black: return Color.black
        case .custom: return Color.blue
        }
    }
}
