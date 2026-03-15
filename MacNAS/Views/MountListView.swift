import SwiftUI
import Shared

/// Main menu content showing mount status and actions.
struct MountListView: View {
    @ObservedObject var appState: AppState
    var onRemount: (MountDefinition) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Server status header
            serverStatusSection

            Divider()

            // Mount list
            if appState.config.mounts.isEmpty {
                Text("No mounts configured")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ForEach(appState.config.mounts) { mount in
                    mountRow(mount)
                }
            }

            Divider()

            menuButton("Settings...") {
                WindowManager.shared.openSettings(appState: appState)
            }

            Divider()

            menuButton("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 4)
        .frame(minWidth: 280)
    }

    private var serverStatusSection: some View {
        HStack(spacing: 8) {
            if !appState.hasNetwork {
                Text("No Network")
                    .foregroundStyle(.red)
                Spacer()
                Image(systemName: "wifi.slash")
                    .foregroundStyle(.red)
            } else if appState.serverReachable {
                Text(appState.config.serverIP.isEmpty ? "No server configured" : appState.config.serverIP)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "server.rack")
                    .foregroundStyle(.green)
            } else {
                Text(appState.config.serverIP.isEmpty ? "No server configured" : "\(appState.config.serverIP) — unreachable")
                    .foregroundStyle(.red)
                Spacer()
                Image(systemName: "server.rack")
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func menuButton(_ title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(MenuItemButtonStyle())
        .disabled(disabled)
    }

    private func mountRow(_ mount: MountDefinition) -> some View {
        let status = appState.status(for: mount)
        let mountPoint = mount.mountPoint(root: appState.config.mountRoot)
        return Button {
            if status == .mounted {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: mountPoint)
            }
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(mount.mountName)
                        .fontWeight(.medium)
                    Text(mount.exportPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if status != .mounted && status != .unknown {
                    Button {
                        onRemount(mount)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .padding(4)
                            .contentShape(Circle())
                    }
                    .buttonStyle(IconHoverButtonStyle())
                }

                Image(systemName: status.systemImage)
                    .foregroundStyle(status.color)

                Text(status.label)
                    .font(.caption)
                    .foregroundStyle(status.color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuItemButtonStyle())
        .disabled(status != .mounted)
    }
}

private struct IconHoverButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isHovered ? .primary : .secondary)
            .background(
                Circle().fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

private struct MenuItemButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: 4).fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
