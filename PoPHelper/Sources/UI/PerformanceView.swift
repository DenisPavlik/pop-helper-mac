import SwiftUI

/// Deliberately NOT a clone of the game's Video menu (which already exposes battle
/// size, shadows, grass, etc.). One button that sets the values which work best on
/// this Mac in a single click — the curated knowledge the in-game menu can't give.
struct PerformanceView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Form {
                Section {
                    LabeledContent {
                        Text(app.macModelName).font(app.font(.body, .medium))
                    } label: {
                        Text(L10n.yourMac.text(for: app.language)).font(app.font(.body))
                    }

                    if app.gameOptimized {
                        Label(L10n.gameOptimized.text(for: app.language), systemImage: "checkmark.seal.fill")
                            .font(app.font(.callout, .medium))
                            .foregroundStyle(.green)
                    }

                    Button {
                        app.optimizeGameForMac()
                    } label: {
                        Label(L10n.optimizeButton.text(for: app.language), systemImage: "bolt.fill")
                            .font(app.font(.body, .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!app.gameConfigExists)

                    if !app.gameConfigExists {
                        Label(L10n.gameConfigMissing.text(for: app.language), systemImage: "exclamationmark.triangle.fill")
                            .font(app.font(.caption)).foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section {
                    bullet("scope", L10n.optBattleSize)
                    bullet("moon.fill", L10n.optShadows)
                    bullet("leaf.fill", L10n.optGrass)
                    Text(L10n.perfNote.text(for: app.language))
                        .font(app.font(.caption)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text(L10n.whatItChanges.text(for: app.language)).font(app.font(.caption, .semibold))
                }

                if let message = app.lastActionMessage {
                    Section {
                        Label(message, systemImage: "info.circle")
                            .font(app.font(.caption)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.performanceTitle.text(for: app.language)).font(app.font(.title2, .semibold))
                Text(L10n.performanceDesc.text(for: app.language))
                    .font(app.font(.caption)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func bullet(_ icon: String, _ text: LocalizedText) -> some View {
        Label {
            Text(text.text(for: app.language))
                .font(app.font(.callout))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon).foregroundStyle(.blue)
        }
    }
}
