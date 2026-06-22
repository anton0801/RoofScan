//
//  Inputs.swift
//  RoofScan
//
//  Styled form controls: text field, slider, selectable chip, severity picker,
//  toggle row, stepper row.
//

import SwiftUI
import UIKit

// MARK: - Text field

struct LabeledField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.rsCaption()).foregroundColor(Theme.textSecondary)
            TextField(placeholder, text: $text)
                .font(.rsBody())
                .foregroundColor(Theme.textPrimary)
                .keyboardType(keyboard)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.bgSoft))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.border, lineWidth: 1))
        }
    }
}

// MARK: - Multiline note field

struct LabeledNote: View {
    let label: String
    @Binding var text: String
    var placeholder: String = "Notes…"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.rsCaption()).foregroundColor(Theme.textSecondary)
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder).font(.rsBody()).foregroundColor(Theme.textDisabled)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                }
                TextEditor(text: $text)
                    .font(.rsBody())
                    .foregroundColor(Theme.textPrimary)
                    .frame(minHeight: 86)
                    .padding(6)
                    .background(Color.clear)
                    .onAppear { UITextView.appearance().backgroundColor = .clear }
            }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.bgSoft))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.border, lineWidth: 1))
        }
    }
}

// MARK: - Slider

struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var unit: String = ""
    var format: String = "%.0f"
    var tint: Color = Theme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).font(.rsBody()).foregroundColor(Theme.textSecondary)
                Spacer()
                Text(String(format: format, value) + (unit.isEmpty ? "" : " \(unit)"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
            }
            Slider(value: $value, in: range, step: step)
                .accentColor(tint)
        }
    }
}

// MARK: - Chip (selectable)

struct Chip: View {
    let label: String
    var icon: String? = nil
    let selected: Bool
    var tint: Color = Theme.primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon).font(.system(size: 12, weight: .bold))
                }
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(selected ? Theme.onPrimary : Theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(selected ? tint : Theme.bgSoft)
            )
            .overlay(
                Capsule().stroke(selected ? tint : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Severity picker (1…5 heat dots)

struct SeverityPicker: View {
    @Binding var severity: Int
    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { severity = i }
                } label: {
                    Text("\(i)")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(i <= severity ? .white : Theme.textDisabled)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(i <= severity ? SeverityPalette.color(severity: i) : Theme.bgSoft)
                        )
                        .overlay(Circle().stroke(Theme.border, lineWidth: i <= severity ? 0 : 1))
                        .scaleEffect(i == severity ? 1.12 : 1)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

// MARK: - Toggle row

struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon).foregroundColor(Theme.primary)
                    .frame(width: 26)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.rsBody()).foregroundColor(Theme.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle).font(.rsCaption()).foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Theme.primary))
        }
    }
}

// MARK: - Checklist row (tap to toggle a checkmark)

struct CheckRow: View {
    let title: String
    var subtitle: String? = nil
    let checked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(checked ? Theme.ok : Theme.textDisabled)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.rsBody()).foregroundColor(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    if let subtitle = subtitle {
                        Text(subtitle).font(.rsCaption()).foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Keyboard dismissal

extension View {
    func rsHideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
