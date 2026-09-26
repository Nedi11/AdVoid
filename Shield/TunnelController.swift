import Foundation
import NetworkExtension
import Observation

/// Installs, starts and stops the packet tunnel VPN configuration.
@MainActor
@Observable
final class TunnelController {
    private(set) var status: NEVPNStatus = .invalid
    private(set) var isInstalled = false
    var lastError: String?

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    var isOn: Bool { status == .connected || status == .connecting || status == .reasserting }

    var statusText: String {
        switch status {
        case .connected: "Protected"
        case .connecting, .reasserting: "Connecting…"
        case .disconnecting: "Stopping…"
        default: "Not protected"
        }
    }

    init() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: nil, queue: .main
        ) { [weak self] note in
            let status = (note.object as? NEVPNConnection)?.status
            MainActor.assumeIsolated {
                if let status { self?.status = status }
            }
        }
    }

    func load() async {
        #if targetEnvironment(simulator)
        lastError = "The Simulator can't run VPNs. Run Shield on an iPhone to turn on protection."
        return
        #endif
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            manager = managers.first
            isInstalled = manager != nil
            status = manager?.connection.status ?? .invalid
        } catch {
            lastError = error.localizedDescription
        }
    }

    func toggle() async {
        if isOn { await stop() } else { await start() }
    }

    func start() async {
        lastError = nil
        do {
            let manager = manager ?? NETunnelProviderManager()
            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = AppGroup.tunnelBundleIdentifier
            proto.serverAddress = "On-device filter"
            manager.protocolConfiguration = proto
            manager.localizedDescription = "Shield"
            manager.isEnabled = true
            // Keep the filter on across reboots and network changes.
            manager.onDemandRules = [NEOnDemandRuleConnect()]
            manager.isOnDemandEnabled = true

            try await manager.saveToPreferences()
            // Saving a new configuration requires a reload before it can be started.
            try await manager.loadFromPreferences()
            self.manager = manager
            isInstalled = true
            try manager.connection.startVPNTunnel()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stop() async {
        guard let manager else { return }
        do {
            // Without this, on-demand would immediately reconnect.
            manager.isOnDemandEnabled = false
            try await manager.saveToPreferences()
        } catch {
            lastError = error.localizedDescription
        }
        manager.connection.stopVPNTunnel()
    }

    /// Restarts a running tunnel so it picks up settings read only at start (upstream DNS).
    func restartIfRunning() async {
        guard isOn, let manager else { return }
        manager.connection.stopVPNTunnel()
        for _ in 0..<50 where manager.connection.status != .disconnected {
            try? await Task.sleep(for: .milliseconds(100))
        }
        try? manager.connection.startVPNTunnel()
    }

    func send(_ message: TunnelMessage) {
        guard let session = manager?.connection as? NETunnelProviderSession,
              session.status == .connected else { return }
        try? session.sendProviderMessage(Data(message.rawValue.utf8))
    }
}
