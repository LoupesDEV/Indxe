import AppKit
import SwiftUI
import ApplicationServices

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
        checkPermissionsAndStartTap()
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
    
    func checkPermissionsAndStartTap() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if trusted {
            permissionTimer?.invalidate()
            permissionTimer = nil
            eventTapManager.delegate = self
            isTapActive = eventTapManager.start()
        } else {
            if permissionTimer == nil {
                permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    if AXIsProcessTrusted() {
                        self.checkPermissionsAndStartTap()
                    }
                }
            }
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
            eventTapDidTriggerCommit()
        }
    }
    
    func eventTapDidTriggerCommit() {
        guard ringState.isVisible else { return }
        
        let selectedIdx = ringState.selectedIndex
        let slices = ringState.activeProfile.slices
        
        ringState.isVisible = false
        overlayPanel?.orderOut(nil)
        
        if let idx = selectedIdx, idx >= 0, idx < slices.count {
            let chosenSlice = slices[idx]
            ActionExecutor.execute(chosenSlice)
        }
    }
    
    func eventTapDidCancel() {
        ringState.isVisible = false
        overlayPanel?.orderOut(nil)
    }
}