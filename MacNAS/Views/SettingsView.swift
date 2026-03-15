import SwiftUI
import Shared

/// Combined settings view with tabs for server config and mount configuration.
struct SettingsView: View {
    @ObservedObject var appState: AppState
    var onDismiss: () -> Void

    enum Tab: Hashable {
        case general
        case mounts
    }

    @State private var selectedTab: Tab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab(appState: appState, onDismiss: onDismiss)
                .tabItem { Label("General", systemImage: "gear") }
                .tag(Tab.general)

            MountSettingsTab(appState: appState, onDismiss: onDismiss)
                .tabItem { Label("Mounts", systemImage: "externaldrive") }
                .tag(Tab.mounts)
        }
        .frame(width: 450, height: 380)
    }
}

// MARK: - General Settings Tab

private struct GeneralSettingsTab: View {
    @ObservedObject var appState: AppState
    var onDismiss: () -> Void

    @State private var serverIP: String = ""
    @State private var mountRoot: String = ""
    @State private var pollInterval: String = ""
    @State private var validationError: String?

    var body: some View {
        VStack(spacing: 16) {
            Form {
                TextField("Server IP:", text: $serverIP, prompt: Text("192.168.1.100"))
                TextField("Mount Root:", text: $mountRoot, prompt: Text("/Volumes/NAS"))
                TextField("Poll Interval (seconds):", text: $pollInterval, prompt: Text("15"))
            }

            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .onAppear {
            serverIP = appState.config.serverIP
            mountRoot = appState.config.mountRoot
            pollInterval = String(Int(appState.config.pollInterval))
        }
    }

    private func save() {
        let ipParts = serverIP.split(separator: ".")
        if serverIP.isEmpty {
            validationError = "Server IP is required"
            return
        }
        if ipParts.count != 4 || !ipParts.allSatisfy({ Int($0) != nil && Int($0)! >= 0 && Int($0)! <= 255 }) {
            validationError = "Invalid IP address"
            return
        }

        if mountRoot.isEmpty || !mountRoot.hasPrefix("/") {
            validationError = "Mount root must be an absolute path"
            return
        }

        guard let poll = TimeInterval(pollInterval), poll >= 5 else {
            validationError = "Poll interval must be at least 5 seconds"
            return
        }

        appState.config.serverIP = serverIP
        appState.config.mountRoot = mountRoot
        appState.config.pollInterval = poll
        appState.saveConfig()

        onDismiss()
    }
}

// MARK: - Mount Settings Tab

private struct MountSettingsTab: View {
    @ObservedObject var appState: AppState
    var onDismiss: () -> Void

    @State private var editingMount: MountDefinition?
    @State private var isAdding = false

    @State private var editExportPath = ""
    @State private var editMountName = ""
    @State private var validationErrors: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(appState.config.mounts) { mount in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(mount.mountName)
                                .fontWeight(.medium)
                            Text(mount.exportPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Edit") {
                            beginEdit(mount)
                        }
                        .buttonStyle(.borderless)
                        .disabled(isEditing)
                    }
                }
                .onDelete { indexSet in
                    appState.config.mounts.remove(atOffsets: indexSet)
                    appState.saveConfig()
                }
            }
            .frame(minHeight: 120)

            if isEditing {
                Divider()
                editForm
            }

            Divider()

            HStack {
                Button("Add Mount") {
                    beginAdd()
                }
                .disabled(isEditing)

                Spacer()

                Button("Done") {
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isEditing)
            }
            .padding()
        }
    }

    private var isEditing: Bool {
        isAdding || editingMount != nil
    }

    private var editForm: some View {
        VStack(spacing: 12) {
            Text(isAdding ? "Add Mount" : "Edit Mount")
                .font(.subheadline)
                .fontWeight(.medium)

            Form {
                TextField("Export Path:", text: $editExportPath, prompt: Text("/volume1/media"))
                TextField("Mount Name:", text: $editMountName, prompt: Text("media"))
            }

            if !validationErrors.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(validationErrors, id: \.self) { error in
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    cancelEdit()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveEdit()
                }
                .disabled(editExportPath.isEmpty || editMountName.isEmpty)
            }
        }
        .padding()
    }

    private func beginAdd() {
        editExportPath = ""
        editMountName = ""
        validationErrors = []
        editingMount = nil
        isAdding = true
    }

    private func beginEdit(_ mount: MountDefinition) {
        editExportPath = mount.exportPath
        editMountName = mount.mountName
        validationErrors = []
        isAdding = false
        editingMount = mount
    }

    private func cancelEdit() {
        isAdding = false
        editingMount = nil
        validationErrors = []
    }

    private func saveEdit() {
        let def = MountDefinition(
            id: editingMount?.id ?? UUID(),
            exportPath: editExportPath,
            mountName: editMountName
        )
        validationErrors = def.validationErrors
        guard validationErrors.isEmpty else { return }

        if let existing = editingMount,
           let idx = appState.config.mounts.firstIndex(where: { $0.id == existing.id }) {
            appState.config.mounts[idx] = def
        } else {
            appState.config.mounts.append(def)
        }
        appState.saveConfig()
        cancelEdit()
    }
}
