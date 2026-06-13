import SwiftUI

enum TextSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }

    /// Bigger than macOS's default across the board — `.medium` (the default here)
    /// already enlarges text so it's comfortable to read.
    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: return .large
        case .medium: return .xLarge
        case .large: return .xxLarge
        }
    }

    var label: LocalizedText {
        switch self {
        case .small: return LocalizedText(en: "Small", uk: "Малий", ru: "Маленький")
        case .medium: return LocalizedText(en: "Medium", uk: "Середній", ru: "Средний")
        case .large: return LocalizedText(en: "Large", uk: "Великий", ru: "Большой")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.settingsTitle.text(for: app.language)).font(.title2.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            Divider()

            Form {
                Section {
                    Picker(selection: $app.textSize) {
                        ForEach(TextSize.allCases) { size in
                            Text(size.label.text(for: app.language)).tag(size)
                        }
                    } label: {
                        Text(L10n.textSize.text(for: app.language))
                    }
                    .pickerStyle(.segmented)

                    Picker(selection: $app.language) {
                        Text("Українська").tag(AppLanguage.ukrainian)
                        Text("Русский").tag(AppLanguage.russian)
                        Text("English").tag(AppLanguage.english)
                    } label: {
                        Text(L10n.language.text(for: app.language))
                    }
                } header: {
                    Text(L10n.appearance.text(for: app.language))
                }

                Section {
                    Text(L10n.textSizePreview.text(for: app.language))
                        .font(.headline)
                    Text(L10n.cosmeticsDesc.text(for: app.language))
                        .font(.body).foregroundStyle(.secondary)
                } header: {
                    Text(L10n.preview.text(for: app.language))
                }
            }
            .formStyle(.grouped)
        }
    }
}
