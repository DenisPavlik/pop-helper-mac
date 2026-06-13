import SwiftUI

struct TweakRow: View {
    @Binding var state: TweakViewState
    @EnvironmentObject var app: AppState

    private var isConflict: Bool {
        if case .conflict = state.status { return true } else { return false }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Toggle(isOn: $state.desiredEnabled) {
                    Text(state.tweak.name.text(for: app.language))
                        .fontWeight(.medium)
                }
                .toggleStyle(.checkbox)
                .disabled(isConflict)
                Spacer()
                statusBadge
            }
            Text(state.tweak.description.text(for: app.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if isConflict {
                Text(L10n.conflictHelp.text(for: app.language))
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if state.desiredEnabled && !state.tweak.params.isEmpty {
                paramEditors
            }
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        let (text, color): (LocalizedText, Color) = {
            if state.isDirty { return (L10n.statusModified, .blue) }
            switch state.status {
            case .applied: return (L10n.statusApplied, .green)
            case .notApplied: return (L10n.statusNotApplied, .secondary)
            case .conflict: return (L10n.statusConflict, .orange)
            }
        }()
        return Text(text.text(for: app.language))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var paramEditors: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(state.tweak.params, id: \.key) { param in
                HStack(spacing: 8) {
                    Text(param.name.text(for: app.language))
                        .font(.caption)
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
                    Text("(\(L10n.original.text(for: app.language)): \(param.originalValue))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.leading, 20)
            }
        }
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
