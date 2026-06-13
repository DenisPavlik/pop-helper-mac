import SwiftUI

/// A single tweak rendered as a card: toggle + name + status badge, description,
/// and inline parameter editors when enabled.
struct TweakCard: View {
    @Binding var state: TweakViewState
    @EnvironmentObject var app: AppState

    private var isConflict: Bool {
        if case .conflict = state.status { return true } else { return false }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Toggle("", isOn: $state.desiredEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(isConflict)
                    .controlSize(.small)

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.tweak.name.text(for: app.language))
                        .font(.headline)
                    Text(state.tweak.description.text(for: app.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                statusBadge
            }

            if isConflict {
                Label(L10n.conflictHelp.text(for: app.language), systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 2)
            } else if state.desiredEnabled && !state.tweak.params.isEmpty {
                Divider()
                paramEditors
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(borderColor, lineWidth: state.isDirty ? 1.5 : 1)
        )
    }

    private var borderColor: Color {
        if state.isDirty { return .accentColor.opacity(0.7) }
        switch state.status {
        case .applied: return .green.opacity(0.4)
        case .conflict: return .orange.opacity(0.55)
        case .notApplied: return Color(nsColor: .separatorColor)
        }
    }

    private var statusBadge: some View {
        let (text, color, icon): (LocalizedText, Color, String) = {
            if state.isDirty { return (L10n.statusModified, .accentColor, "circle.dashed") }
            switch state.status {
            case .applied: return (L10n.statusApplied, .green, "checkmark.circle.fill")
            case .notApplied: return (L10n.statusNotApplied, .secondary, "circle")
            case .conflict: return (L10n.statusConflict, .orange, "exclamationmark.triangle.fill")
            }
        }()
        return Label(text.text(for: app.language), systemImage: icon)
            .labelStyle(.titleAndIcon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
            .fixedSize()
    }

    private var paramEditors: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(state.tweak.params, id: \.key) { param in
                HStack(spacing: 10) {
                    Text(param.name.text(for: app.language))
                        .font(.callout)
                        .frame(minWidth: 120, alignment: .leading)
                    if let presets = param.presets, !presets.isEmpty {
                        Picker("", selection: valueBinding(param)) {
                            ForEach(presets, id: \.value) { preset in
                                Text("\(preset.label.text(for: app.language)) (\(preset.value))")
                                    .tag(preset.value)
                            }
                            if !presets.contains(where: { $0.value == currentValue(param) }) {
                                Text("\(currentValue(param))").tag(currentValue(param))
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    } else {
                        TextField("", value: valueBinding(param), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                        Stepper("", value: valueBinding(param), in: range(of: param))
                            .labelsHidden()
                    }
                    Spacer(minLength: 4)
                    Text("\(L10n.original.text(for: app.language)): \(param.originalValue)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.leading, 2)
    }

    private func currentValue(_ param: TweakParam) -> Int {
        state.desiredValues[param.key] ?? param.defaultValue
    }

    private func valueBinding(_ param: TweakParam) -> Binding<Int> {
        Binding(
            get: { currentValue(param) },
            set: { state.desiredValues[param.key] = $0.clamped(to: range(of: param)) })
    }

    private func range(of param: TweakParam) -> ClosedRange<Int> {
        (param.min ?? Int(Int32.min))...(param.max ?? Int(Int32.max))
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
