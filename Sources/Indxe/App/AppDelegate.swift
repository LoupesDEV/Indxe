import AppKit
import SwiftUI
import ApplicationServices
import Observation

@Observable
final class AppDelegate: NSObject, NSApplicationDelegate, EventTapDelegate {
    let ringState = RingState()
    let eventTapManager = EventTapManager()
    private var overlayPanel: OverlayPanel?
    private var settingsWindow: NSWindow?
    private var permissionTimer: Timer?
    
    var isTapActive: Bool = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        setupOverlayPanel()
        checkPermissionsAndStartTap(promptIfNeeded: true)
        startHealthCheckTimer()
    }
    
    private func setupOverlayPanel() {
        let rect = NSRect(x: 0, y: 0, width: 340, height: 340)
        let rootView = RadialMenuView(state: ringState)
        let panel = OverlayPanel(contentRect: rect, rootView: rootView)
        self.overlayPanel = panel
    }
    
    func openSettingsWindow() {
        if settingsWindow == nil {
            let hostingController = NSHostingController(rootView: SettingsView(store: ProfileStore.shared))
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Indxe — Configuration des Menus Radiaux"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 900, height: 600))
            window.center()
            window.isReleasedWhenClosed = false
            self.settingsWindow = window
        }
        
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    func checkPermissionsAndStartTap(promptIfNeeded: Bool = false) {
        eventTapManager.delegate = self
        
        if eventTapManager.start() {
            isTapActive = true
            return
        }
        
        isTapActive = false
        if promptIfNeeded {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    }
    
    private func startHealthCheckTimer() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let currentlyRunning = self.eventTapManager.isRunning
            if currentlyRunning != self.isTapActive {
                self.isTapActive = currentlyRunning
            }
            if !currentlyRunning && AXIsProcessTrusted() {
                self.isTapActive = self.eventTapManager.start()
            }
        }
    }
    
    func resetTCCPermissions() {
        eventTapManager.stop()
        isTapActive = false
        let bundleId = Bundle.main.bundleIdentifier ?? "com.cyrex.Indxe"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleId]
        try? process.run()
        process.waitUntilExit()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.checkPermissionsAndStartTap(promptIfNeeded: true)
        }
    }
    
    // MARK: - EventTapDelegate
    
    func eventTapDidTriggerShow(at screenPoint: CGPoint) {
        let profile = ContextResolver.shared.resolveCurrentProfile()
        ringState.activeProfile = profile
        ringState.centerScreenPoint = screenPoint
        ringState.currentMouseScreenPoint = screenPoint
        ringState.selectedIndex = nil
        ringState.isVisible = true
        
        overlayPanel?.showCentered(at: screenPoint)
    }
    
    func eventTapDidMoveCursor(to screenPoint: CGPoint) {
        guard ringState.isVisible else { return }
        let shouldCommitImmediately = ringState.updateCursorPosition(screenPoint)
        if shouldCommitImmediately {
            eventTapManager.endActiveSessionImmediately()
            commitCurrentSelection()
        }
    }
    
    func eventTapDidTriggerCommit(at screenPoint: CGPoint) {
        guard ringState.isVisible else { return }
        _ = ringState.updateCursorPosition(screenPoint)
        commitCurrentSelection()
    }
    
    private func commitCurrentSelection() {
        let selectedIdx = ringState.selectedIndex
        let slices = ringState.activeProfile.slices
        
        ringState.isVisible = false
        overlayPanel?.orderOut(nil)
        
        if let idx = selectedIdx, idx >= 0, idx < slices.count {
            let chosenSlice = slices[idx]
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            ActionExecutor.execute(chosenSlice)
        }
    }
    
    func eventTapDidCancel() {
        ringState.isVisible = false
        overlayPanel?.orderOut(nil)
    }
}