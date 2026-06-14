import SwiftUI

/// One tweak as a compact list row: checkbox + name + short description + status,
/// with inline parameter editors shown only when the tweak is enabled.
struct TweakRow: View {
    @Binding var state: TweakViewState
    @EnvironmentObject var app: AppState

    private var isConflict: Bool {
        if case .conflict = state.status { return true } else { return false }
    }

    private var isAppliedExternally: Bool {
        if case .appliedExternally = state.status { return true } else { return false }
    }

    /// The toggle is locked whenever we can't cleanly apply/revert the tweak.
    private var isLocked: Bool { isConflict || isAppliedExternally }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Toggle("", isOn: $state.desiredEnabled)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .disabled(isLocked)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if state.tweak.requiresNewGame == true {
                            Text("*")
                                .font(app.font(.body, .bold))
                                .foregroundStyle(.orange)
                                .help(L10n.requiresNewGame.text(for: app.language))
                        }
                        Text(state.tweak.name.text(for: app.language))
                            .font(app.font(.body, .medium))
                    }
                    Text(state.tweak.description.text(for: app.language))
                        .font(app.font(.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if state.tweak.requiresNewGame == true {
                        Label(L10n.requiresNewGame.text(for: app.language), systemImage: "asterisk.circle.fill")
                            .font(app.font(.caption2))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)
                statusBadge
            }

            if isConflict {
                Text(L10n.conflictHelp.text(for: app.language))
                    .font(app.font(.caption))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 26)
            } else if isAppliedExternally {
                Text(L10n.appliedExternallyHelp.text(for: app.language))
                    .font(app.font(.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 26)
            } else if state.desiredEnabled {
                if !state.tweak.params.isEmpty {
                    paramEditors
                        .padding(.leading, 26)
                }
                if let tip = state.tweak.recommendation {
                    Label {
                        Text(tip.text(for: app.language))
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "lightbulb")
                    }
                    .font(app.font(.caption2))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 26)
                }
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture { if !isLocked { state.desiredEnabled.toggle() } }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if state.isDirty {
            badge(L10n.statusModified, .accentColor, "circle.dashed")
        } else {
            switch state.status {
            case .applied: badge(L10n.statusApplied, .green, "checkmark.circle.fill")
            case .appliedExternally: badge(L10n.statusAppliedExternally, .green, "checkmark.seal.fill")
            case .conflict: badge(L10n.statusConflict, .orange, "exclamationmark.triangle.fill")
            case .notApplied: EmptyView()
            }
        }
    }

    private func badge(_ text: LocalizedText, _ color: Color, _ icon: String) -> some View {
        Label(text.text(for: app.language), systemImage: icon)
            .labelStyle(.titleAndIcon)
            .font(app.font(.caption2, .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
            .fixedSize()
    }

    private var paramEditors: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(state.tweak.params, id: \.key) { param in
                HStack(spacing: 8) {
                    Text(param.name.text(for: app.language))
                        .font(app.font(.caption))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 110, alignment: .leading)
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
                        .controlSize(.small)
                        .fixedSize()
                    } else {
                        TextField("", value: valueBinding(param), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                            .frame(width: 80)
                        Stepper("", value: valueBinding(param), in: range(of: param))
                            .labelsHidden()
                            .controlSize(.small)
                    }
                    HStack(spacing: 5) {
                        Text("\(L10n.original.text(for: app.language)): \(param.originalValue)")
                        // Our pre-filled default is the value we recommend; show it as an
                        // orientation for players unfamiliar with the mechanic.
                        if param.defaultValue != param.originalValue {
                            Text("·")
                            Text("\(L10n.recommended.text(for: app.language)) \(param.defaultValue)")
                                .help(L10n.recommendedFull.text(for: app.language))
                        }
                    }
                    .font(app.font(.caption2))
                    .foregroundStyle(.tertiary)
                }
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
