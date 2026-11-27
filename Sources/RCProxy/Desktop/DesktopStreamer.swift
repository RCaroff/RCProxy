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
    /// The names of the connected computers. `executing` is true when the requests of the app
    /// are performed by one of them instead of the app.
    case connected([String], executing: Bool)
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
///
/// When a Mac performed the requests of the app the last time, the requests made before it is back
/// wait for it (see `ExecutionGate`): the ones of the launch can be mocked too.
final class DesktopStreamer: Sendable {

    static let shared = DesktopStreamer()

    private static let enabledKey = "RCProxy.desktopStreamingEnabled"
    private static let expectsExecutorKey = "RCProxy.desktopRunsRequests"

    /// How long the requests wait for the invitation of a Mac that is expected.
    static let invitationDelay: TimeInterval = 5
    /// How long they wait, once the Mac is allowed, for the connection to settle.
    static let connectionDelay: TimeInterval = 8

    private struct Handover: Sendable {
        var gate = ExecutionGate()
        var didExpectAtLaunch = false
        var observesForeground = false
    }

    private let advertiser = OSAllocatedUnfairLock<RemoteAdvertiser?>(initialState: nil)
    private let handover = OSAllocatedUnfairLock(initialState: Handover())

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
            // Turned off by hand: no Mac is expected at the next launches.
            setExpectsExecutor(false)
        }
    }

    /// Starts streaming again if the switch was left on. Cheap, and safe to call from any thread.
    func resumeIfEnabled() {
        guard isEnabled, advertiser.withLock({ $0 == nil }) else { return }
        // First use of RCProxy in this launch: the Mac needs a moment to find the app and to connect.
        let isLaunch = handover.withLock { state -> Bool in
            guard !state.didExpectAtLaunch else { return false }
            state.didExpectAtLaunch = true
            return true
        }
        if isLaunch {
            expectExecutor(for: Self.invitationDelay)
        }
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
            releaseHeldRequests()
            return
        }
        observeForeground()

        let advertiser = RemoteAdvertiser(
            device: DeviceDescription.current(),
            handlers: RemoteAdvertiser.Handlers(
                shouldAccept: { viewer in
                    let accepted = await DesktopTrust.shouldAccept(viewer)
                    if accepted {
                        // The Mac is on its way: the requests wait until the connection has settled.
                        DesktopStreamer.shared.expectExecutor(for: DesktopStreamer.connectionDelay)
                    }
                    return accepted
                },
                viewerDidConnect: { viewerID in
                    RequestRecorder.shared.viewerConnected(viewerID: viewerID)
                },
                statusDidChange: { status in
                    DesktopStreamer.shared.executorsDidChange(status)
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
        releaseHeldRequests()
    }

    // MARK: Sending

    func broadcast(_ item: RequestItem) {
        advertiser.withLock { $0 }?.broadcast(item)
    }

    func sendInitialState(_ items: [RequestItem], toViewer viewerID: String) {
        advertiser.withLock { $0 }?.sendInitialState(items, toViewer: viewerID)
    }

    // MARK: Delegated requests

    /// Hands a request over to RCProxy Desktop when it asked to perform the requests of the app.
    /// `completion` receives `nil` when the app has to perform the request itself.
    func execute(_ request: RemoteExecutionRequest, completion: @escaping @Sendable (RemoteExecutionResult?) -> Void) {
        // A Mac is expected but not there yet: the request waits for it.
        if handover.withLock({ $0.gate.hold(request, completion: completion, now: Date()) }) {
            return
        }
        guard let advertiser = advertiser.withLock({ $0 }) else {
            completion(nil)
            return
        }
        advertiser.execute(request, completion: completion)
    }

    func cancelExecution(id: String) {
        if handover.withLock({ $0.gate.cancel(id: id) }) {
            return
        }
        advertiser.withLock { $0 }?.cancelExecution(id: id)
    }

    // MARK: Waiting for the Mac

    /// A Mac performed the requests of the app the last time, and is likely to do it again.
    private var expectsExecutor: Bool {
        if let known = UserDefaults.standard.object(forKey: Self.expectsExecutorKey) as? Bool {
            return known
        }
        // Never recorded (first launch with this version): a Mac that is always allowed usually comes back.
        return DesktopTrust.hasTrustedDesktops
    }

    private func setExpectsExecutor(_ expected: Bool) {
        guard UserDefaults.standard.object(forKey: Self.expectsExecutorKey) as? Bool != expected else { return }
        UserDefaults.standard.set(expected, forKey: Self.expectsExecutorKey)
    }

    /// Makes the requests wait for a Mac for a while, when one is expected.
    private func expectExecutor(for delay: TimeInterval) {
        guard isEnabled, expectsExecutor else { return }
        handover.withLock { $0.gate.expectExecutor(until: Date().addingTimeInterval(delay)) }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay + 0.05) { [self] in
            guard let late = handover.withLock({ $0.gate.expire(now: Date()) }) else { return }
            // Nobody came. The app performs its requests itself, and does not wait at the next launch:
            // the wait resumes once a Mac has performed the requests again.
            setExpectsExecutor(false)
            late.forEach { $0.completion(nil) }
        }
    }

    /// Called on the queue of the advertiser, each time viewers come and go.
    private func executorsDidChange(_ status: RemoteAdvertiser.Status) {
        switch status {
        case .advertising(_, let executors) where !executors.isEmpty:
            let waiting = handover.withLock { $0.gate.executorArrived() }
            setExpectsExecutor(true)
            guard !waiting.isEmpty else { return }
            let advertiser = advertiser.withLock { $0 }
            for held in waiting {
                if let advertiser {
                    advertiser.execute(held.request, completion: held.completion)
                } else {
                    held.completion(nil)
                }
            }
        case .advertising:
            handover.withLock { $0.gate.executorLeft() }
        case .stopped, .failed:
            releaseHeldRequests()
        }
    }

    /// Gives the requests that were waiting back to the app.
    private func releaseHeldRequests() {
        handover.withLock { $0.gate.giveUp() }.forEach { $0.completion(nil) }
    }

    /// Back from the background, the link with the Mac has to be made again: same wait as at launch.
    @MainActor
    private func observeForeground() {
        let isFirst = handover.withLock { state -> Bool in
            guard !state.observesForeground else { return false }
            state.observesForeground = true
            return true
        }
        guard isFirst else { return }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil
        ) { _ in
            let streamer = DesktopStreamer.shared
            guard streamer.advertiser.withLock({ $0 != nil }) else { return }
            streamer.expectExecutor(for: DesktopStreamer.invitationDelay)
        }
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
        case .advertising(let viewers, let executors):
            self = viewers.isEmpty ? .waiting : .connected(viewers, executing: !executors.isEmpty)
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

    /// At least one computer was chosen to be always allowed.
    static var hasTrustedDesktops: Bool {
        !(UserDefaults.standard.stringArray(forKey: trustedViewersKey) ?? []).isEmpty
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
