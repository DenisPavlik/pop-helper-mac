import SwiftUI
import AppKit

struct CosmeticsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.cosmetics.text(for: app.language)).font(app.font(.title2, .semibold))
                    Text(L10n.cosmeticsDesc.text(for: app.language))
                        .font(app.font(.caption)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            Divider()
            if app.packStates.isEmpty {
                ContentUnavailableView(L10n.packUnavailable.text(for: app.language), systemImage: "paintbrush")
            } else {
                List {
                    ForEach(app.packStates) { state in
                        PackCard(state: binding(for: state.id))
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func binding(for id: String) -> Binding<PackViewState> {
        Binding(
            get: { app.packStates.first(where: { $0.id == id }) ?? app.packStates[0] },
            set: { newValue in
                if let i = app.packStates.firstIndex(where: { $0.id == id }) {
                    app.packStates[i] = newValue
                }
            })
    }
}

struct PackCard: View {
    @Binding var state: PackViewState
    @EnvironmentObject var app: AppState

    private var isChoice: Bool { state.pack.kind == .choice }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Toggle("", isOn: Binding(
                    get: { state.installed },
                    set: { on in
                        if on {
                            app.installPack(state.pack, optionId: isChoice ? state.optionId : nil)
                        } else {
                            app.uninstallPack(state.pack)
                        }
                    }))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .disabled(!state.available)

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.pack.name.text(for: app.language)).font(app.font(.body, .medium))
                    Text(state.pack.description.text(for: app.language))
                        .font(app.font(.caption)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if state.installed {
                    Label(L10n.installed.text(for: app.language), systemImage: "checkmark.circle.fill")
                        .font(app.font(.caption2, .semibold))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(.green.opacity(0.15), in: Capsule())
                        .foregroundStyle(.green)
                        .fixedSize()
                }
            }

            if !state.available {
                Label(L10n.packUnavailable.text(for: app.language), systemImage: "exclamationmark.triangle.fill")
                    .font(app.font(.caption)).foregroundStyle(.orange).padding(.leading, 26)
            } else if isChoice, let options = state.pack.options {
                HStack(alignment: .top, spacing: 12) {
                    Picker(L10n.chooseStyle.text(for: app.language), selection: Binding(
                        get: { state.optionId ?? options.first?.id ?? "" },
                        set: { newId in
                            state.optionId = newId
                            if state.installed { app.installPack(state.pack, optionId: newId) }
                        })) {
                        ForEach(options) { opt in
                            Text(opt.name.text(for: app.language)).tag(opt.id)
                        }
                    }
                    .frame(maxWidth: 220)
                    preview(options: options)
                }
                .padding(.leading, 26)
            }
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private func preview(options: [PackOption]) -> some View {
        if let optId = state.optionId ?? options.first?.id,
           let opt = options.first(where: { $0.id == optId }),
           let url = app.packPreviewURL(state.pack, opt),
           let img = NSImage(contentsOf: url) {
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 64, height: 64)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
