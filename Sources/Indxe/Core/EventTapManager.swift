import Foundation
import CoreGraphics
import AppKit

protocol EventTapDelegate: AnyObject {
    func eventTapDidTriggerShow(at screenPoint: CGPoint)
    func eventTapDidMoveCursor(to screenPoint: CGPoint)
    func eventTapDidTriggerCommit(at screenPoint: CGPoint)
    func eventTapDidCancel()
}

final class EventTapManager {
    weak var delegate: EventTapDelegate?
    
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    fileprivate var isMenuCurrentlyActive: Bool = false
    fileprivate var pressTimestamp: TimeInterval = 0
    fileprivate var initialPressLocation: CGPoint = .zero
    fileprivate var maxDisplacement: CGFloat = 0
    
    /// Signature apposée sur les clics droits synthétiques ré-injectés (Pass-through)
    private let syntheticEventTag: Int64 = 0x494E4458 // "INDX"
    
    var isRunning: Bool {
        guard let tap = eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }
    
    func start() -> Bool {
        stop()
        
        let trackedEvents: [CGEventType] = [
            .rightMouseDown,
            .rightMouseUp,
            .rightMouseDragged,
            .leftMouseDown,
            .leftMouseDragged,
            .mouseMoved,
            .keyDown
        ]
        
        let eventMask: CGEventMask = trackedEvents.reduce(0) { mask, type in
            mask | (CGEventMask(1) << CGEventMask(type.rawValue))
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: selfPtr
        ) else {
            return false
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return CGEvent.tapIsEnabled(tap: tap)
    }
    
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isMenuCurrentlyActive = false
    }
    
    func endActiveSessionImmediately() {
        isMenuCurrentlyActive = false
    }
    
    /// Convertit les coordonnées Quartz (origine en haut à gauche) en coordonnées Cocoa (origine en bas à gauche)
    private func cocoaScreenPoint(from cgEvent: CGEvent) -> CGPoint {
        let cgLoc = cgEvent.location
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 1080.0
        return CGPoint(x: cgLoc.x, y: primaryScreenHeight - cgLoc.y)
    }
    
    fileprivate func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        
        if event.getIntegerValueField(.eventSourceUserData) == syntheticEventTag {
            return Unmanaged.passUnretained(event)
        }
        
        // Laisse les clics normaux fonctionner dans la fenêtre de configuration d'Indxe
        if !isMenuCurrentlyActive,
           NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return Unmanaged.passUnretained(event)
        }
        
        let currentPoint = cocoaScreenPoint(from: event)
        
        // Touche Échap (53) ou clic gauche pendant que le menu est ouvert
        if isMenuCurrentlyActive {
            if type == .keyDown && event.getIntegerValueField(.keyboardEventKeycode) == 53 {
                isMenuCurrentlyActive = false
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.eventTapDidCancel()
                }
                return nil
            }
            if type == .leftMouseDown {
                isMenuCurrentlyActive = false
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.eventTapDidTriggerCommit(at: currentPoint)
                }
                return nil
            }
        }
        
        // 1. APPUI SUR LE CLIC DROIT UNIQUEMENT
        if type == .rightMouseDown {
            isMenuCurrentlyActive = true
            pressTimestamp = ProcessInfo.processInfo.systemUptime
            initialPressLocation = currentPoint
            maxDisplacement = 0
            
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.eventTapDidTriggerShow(at: currentPoint)
            }
            return nil
        }
        
        // 2. GLISSEMENT DU CURSEUR PENDANT QUE LE MENU EST OUVERT
        if isMenuCurrentlyActive && (
            type == .rightMouseDragged ||
            type == .leftMouseDragged ||
            type == .mouseMoved
        ) {
            let dist = hypot(currentPoint.x - initialPressLocation.x, currentPoint.y - initialPressLocation.y)
            if dist > maxDisplacement {
                maxDisplacement = dist
            }
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.eventTapDidMoveCursor(to: currentPoint)
            }
            return nil
        }
        
        // 3. RELÂCHEMENT DU CLIC DROIT UNIQUEMENT
        if type == .rightMouseUp {
            guard isMenuCurrentlyActive else {
                return nil
            }
            
            isMenuCurrentlyActive = false
            let elapsed = ProcessInfo.processInfo.systemUptime - pressTimestamp
            let cgLocation = event.location
            
            if ProfileStore.shared.allowQuickRightClickPassThrough && elapsed < 0.18 && maxDisplacement < 15.0 {
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.eventTapDidCancel()
                    self?.postNativeRightClick(at: cgLocation)
                }
                return nil
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.eventTapDidTriggerCommit(at: currentPoint)
            }
            return nil
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func postNativeRightClick(at cgPoint: CGPoint) {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(mouseEventSource: source, mouseType: .rightMouseDown, mouseCursorPosition: cgPoint, mouseButton: .right),
              let up = CGEvent(mouseEventSource: source, mouseType: .rightMouseUp, mouseCursorPosition: cgPoint, mouseButton: .right) else {
            return
        }
        down.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
        up.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()
    return manager.handleEvent(proxy: proxy, type: type, event: event)
}