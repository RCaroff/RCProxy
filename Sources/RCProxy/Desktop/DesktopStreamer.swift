//
//  DesktopStreamer.swift
//  RCProxy
//
//  Streams the recorded requests to RCProxy Desktop.
//

import Foundation
import UIKit
import os
import RCProxyCore

/// State of the link with RCProxy Desktop, as shown in the in-app UI.
enum DesktopStreamingStatus: Sendable, Equatable {
    /// The switch is off: the app is invisible to RCProxy Desktop.
    case disabled
    /// Visible on the local network, no computer connected.
    case waiting
    /// The names of the connected computers.
    case connected([String])
    case failed(String)
}

/// Publishes the state of the link to the in-app UI.
@MainActor
final class DesktopStreamingMonitor: ObservableObject {
    static let shared = DesktopStreamingMonitor()

    /// The position of the switch.
    @Published fileprivate(set) var isEnabled = DesktopStreamer.shared.isEnabled
    @Published private(set) var status: DesktopStreamingStatus = .disabled

    fileprivate func update(_ status: DesktopStreamingStatus) {
        guard self.status != status else { return }
        self.status = status
    }
}

/// Streams the recorded requests to RCProxy Desktop while the switch of the requests list is on.
///
/// The position of the switch is remembered: once turned on, streaming resumes by itself at the next
/// launches, as soon as RCProxy is used, so that the very first requests of the app can be watched too.
final class DesktopStreamer: Sendable {

    static let shared = DesktopStreamer()

    private static let enabledKey = "RCProxy.desktopStreamingEnabled"

    private let advertiser = OSAllocatedUnfairLock<RemoteAdvertiser?>(initialState: nil)

    private init() {}

    // MARK: Switch

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    /// Turns streaming on or off, and remembers the choice. Called by the switch.
    @MainActor
    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        DesktopStreamingMonitor.shared.isEnabled = enabled
        if enabled {
            startAdvertising()
        } else {
            stopAdvertising()
        }
    }

    /// Starts streaming again if the switch was left on. Cheap, and safe to call from any thread.
    func resumeIfEnabled() {
        guard isEnabled, advertiser.withLock({ $0 == nil }) else { return }
        // UIKit (the description of the device) belongs to the main actor.
        Task { @MainActor in
            // The switch may have been turned off in the meantime.
            if isEnabled {
                startAdvertising()
            }
        }
    }

    @MainActor
    private func startAdvertising() {
        guard advertiser.withLock({ $0 == nil }) else { return }

        // Without these keys, iOS and tvOS silently refuse to advertise the app: say it loudly.
        let missing = Self.missingBonjourServices
        guard missing.isEmpty else {
            let message = "Add \(missing.joined(separator: " and ")) to NSBonjourServices in the Info.plist of the app."
            print("[RCProxy] ⚠️ RCProxy Desktop cannot see this app. \(message)")
            DesktopStreamingMonitor.shared.update(.failed(message))
            return
        }

        let advertiser = RemoteAdvertiser(
            device: DeviceDescription.current(),
            handlers: RemoteAdvertiser.Handlers(
                shouldAccept: { viewer in
                    await DesktopTrust.shouldAccept(viewer)
                },
                viewerDidConnect: { viewerID in
                    RequestRecorder.shared.viewerConnected(viewerID: viewerID)
                },
                statusDidChange: { status in
                    Task { @MainActor in
                        // A late report from an advertiser that was stopped must not undo the switch.
                        guard DesktopStreamer.shared.isEnabled else { return }
                        DesktopStreamingMonitor.shared.update(DesktopStreamingStatus(status))
                    }
                }
            )
        )
        self.advertiser.withLock { $0 = advertiser }
        DesktopStreamingMonitor.shared.update(.waiting)
        advertiser.start()
    }

    @MainActor
    private func stopAdvertising() {
        let previous = advertiser.withLock { current -> RemoteAdvertiser? in
            let previous = current
            current = nil
            return previous
        }
        previous?.stop()
        DesktopStreamingMonitor.shared.update(.disabled)
    }

    // MARK: Sending

    func broadcast(_ item: RequestItem) {
        advertiser.withLock { $0 }?.broadcast(item)
    }

    func sendInitialState(_ items: [RequestItem], toViewer viewerID: String) {
        advertiser.withLock { $0 }?.sendInitialState(items, toViewer: viewerID)
    }

    // MARK: Helpers

    private static var missingBonjourServices: [String] {
        let declared = Bundle.main.object(forInfoDictionaryKey: "NSBonjourServices") as? [String] ?? []
        return RemoteLink.bonjourServices.filter { !declared.contains($0) }
    }
}

private extension DesktopStreamingStatus {
    init(_ status: RemoteAdvertiser.Status) {
        switch status {
        case .stopped:
            self = .disabled
        case .advertising(let viewers):
            self = viewers.isEmpty ? .waiting : .connected(viewers)
        case .failed(let message):
            self = .failed(message)
        }
    }
}

// MARK: - Device description

@MainActor
enum DeviceDescription {

    private static let installationIDKey = "RCProxy.installationID"

    static func current() -> RemoteDeviceInfo {
        let bundle = Bundle.main
        let appName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? ProcessInfo.processInfo.processName
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let appVersion = [shortVersion, build.map { "(\($0))" }].compactMap { $0 }.joined(separator: " ")

        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif

        return RemoteDeviceInfo(
            id: installationID,
            name: UIDevice.current.name,
            model: UIDevice.current.model,
            systemName: UIDevice.current.systemName,
            systemVersion: UIDevice.current.systemVersion,
            appName: appName,
            appIdentifier: bundle.bundleIdentifier ?? "",
            appVersion: appVersion,
            libraryVersion: RCProxy.version,
            isSimulator: isSimulator
        )
    }

    /// Identifies this installation of the app, so that RCProxy Desktop recognizes it across launches.
    private static var installationID: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: installationIDKey) {
            return existing
        }
        let identifier = UUID().uuidString
        defaults.set(identifier, forKey: installationIDKey)
        return identifier
    }
}

// MARK: - Trust

/// Decides whether a computer may receive the requests of the app. Requests can hold tokens and
/// personal data: the switch makes the app visible, but each computer still has to be allowed once.
enum DesktopTrust {

    private static let trustedViewersKey = "RCProxy.trustedDesktops"

    /// Computers the user chose to always allow are accepted right away; the others are asked about.
    static func shouldAccept(_ viewer: RemoteViewerInfo) async -> Bool {
        if isTrusted(viewer.id) {
            return true
        }
        switch await DesktopPairingAlert.ask(viewer) {
        case .deny:
            return false
        case .allowOnce:
            return true
        case .alwaysAllow:
            trust(viewer.id)
            return true
        }
    }

    private static func isTrusted(_ viewerID: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: trustedViewersKey) ?? []).contains(viewerID)
    }

    private static func trust(_ viewerID: String) {
        var trusted = UserDefaults.standard.stringArray(forKey: trustedViewersKey) ?? []
        guard !trusted.contains(viewerID) else { return }
        trusted.append(viewerID)
        UserDefaults.standard.set(trusted, forKey: trustedViewersKey)
    }
}

/// The alert asking the user whether a computer may receive the requests of the app.
@MainActor
enum DesktopPairingAlert {

    enum Answer: Sendable {
        case deny, allowOnce, alwaysAllow
    }

    private static var isAsking = false
    /// The invitation sent by RCProxy Desktop expires after a minute: answer before that.
    private static let timeout: Duration = .seconds(50)

    static func ask(_ viewer: RemoteViewerInfo) async -> Answer {
        // One question at a time. RCProxy Desktop can simply ask again.
        guard !isAsking, let presenter = topViewController() else { return .deny }
        isAsking = true
        defer { isAsking = false }

        return await withCheckedContinuation { (continuation: CheckedContinuation<Answer, Never>) in
            let answer = SingleAnswer(continuation)
            let alert = UIAlertController(
                title: "RCProxy Desktop",
                message: "“\(viewer.name)” would like to receive the network requests of this app.\n\nCode: \(viewer.pairingCode)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Don’t Allow", style: .cancel) { _ in answer.give(.deny) })
            alert.addAction(UIAlertAction(title: "Allow Once", style: .default) { _ in answer.give(.allowOnce) })
            alert.addAction(UIAlertAction(title: "Always Allow", style: .default) { _ in answer.give(.alwaysAllow) })
            presenter.present(alert, animated: true)

            Task { @MainActor in
                try? await Task.sleep(for: timeout)
                if answer.give(.deny) {
                    alert.dismiss(animated: true)
                }
            }
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    /// Makes sure the continuation is resumed exactly once.
    @MainActor
    private final class SingleAnswer {
        private var continuation: CheckedContinuation<Answer, Never>?

        init(_ continuation: CheckedContinuation<Answer, Never>) {
            self.continuation = continuation
        }

        @discardableResult
        func give(_ answer: Answer) -> Bool {
            guard let continuation else { return false }
            self.continuation = nil
            continuation.resume(returning: answer)
            return true
        }
    }
}
