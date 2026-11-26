//
//  DesktopStreamingSwitch.swift
//  RCProxy
//
//  The switch of the requests list that starts and stops the stream to RCProxy Desktop.
//

import SwiftUI

/// While the switch is on, RCProxy Desktop can see the app and receive its requests.
/// While it is off, the app is invisible to it.
struct DesktopStreamingSwitch: View {
    @ObservedObject private var monitor = DesktopStreamingMonitor.shared

    var body: some View {
        #if os(tvOS)
        // tvOS: the toggle is the whole row, and takes the focus. The status is its second line, so that
        // it follows the colours of the focused row.
        toggle {
            VStack(alignment: .leading, spacing: 6) {
                Text("RCProxy Desktop")
                status
            }
        }
        .onAppear { DesktopStreamer.shared.resumeIfEnabled() }
        #else
        VStack(alignment: .leading, spacing: 2) {
            toggle { Text("RCProxy Desktop") }
            status
        }
        .padding(.vertical, 4)
        .onAppear { DesktopStreamer.shared.resumeIfEnabled() }
        #endif
    }

    /// A plain system toggle: a switch on iOS, an On / Off row on tvOS.
    private func toggle<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        Toggle(isOn: Binding(
            get: { monitor.isEnabled },
            set: { DesktopStreamer.shared.setEnabled($0) }
        ), label: label)
        // The requests list tints its controls in black or white: keep the system colour here.
        .tint(Color(uiColor: .systemGreen))
        .accessibilityIdentifier("RCProxy.desktopSwitch")
    }

    private var status: some View {
        Text(statusText)
            .font(.footnote)
            .foregroundColor(isTV ? nil : statusColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("RCProxy.desktopStatus")
    }

    private var statusText: String {
        switch monitor.status {
        case .disabled:
            return "Turn on to watch the requests live on your Mac."
        case .waiting:
            return "Visible to RCProxy Desktop. Connect from your Mac."
        case .connected(let computers):
            return "Streaming to \(computers.joined(separator: ", "))"
        case .failed(let message):
            return message
        }
    }

    private var statusColor: Color {
        switch monitor.status {
        case .disabled, .waiting: return .secondary
        case .connected: return .green
        case .failed: return .orange
        }
    }
}
