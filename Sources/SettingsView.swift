// SettingsView.swift — the configuration window (the reason for going native).

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section("Transmission server") {
                TextField("RPC URL", text: $state.rpcURLString,
                          prompt: Text(AppState.defaultRPC))
            }

            Section {
                TextField("Username", text: $state.username)
                SecureField("Password", text: $state.password)
            } header: {
                Text("Authentication (optional)")
            } footer: {
                Text("Leave blank if your Transmission server doesn't require a login.")
            }

            Section {
                HStack {
                    Button("Test connection") { state.testConnection() }
                    Button("Save") { state.saveSettings() }
                        .keyboardShortcut(.defaultAction)
                    Spacer()
                    Text(state.lastStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .navigationTitle("Magnetize Settings")
    }
}
