import Foundation
import CoreGraphics
import AppKit

protocol EventTapDelegate: AnyObject {
    func eventTapDidTriggerShow(at screenPoint: CGPoint)
    func eventTapDidMoveCursor(to screenPoint: CGPoint)
    func eventTapDidTriggerCommit()
    func eventTapDidCancel()
}

final class EventTapManager {
    weak var delegate: EventTapDelegate?
    
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    fileprivate var isMenuCurrentlyActive: Bool = false
    fileprivate var pressTimestamp: TimeInterval = 0
    fileprivate var initialPressLocation: CGPoint = .zero
    fileprivate var didSelectSliceDuringHold: Bool = false
    
    private let syntheticEventTag: Int64 = 0x494E4458 // "INDX"
    var extraTriggerButtons: Set<Int64> = [2, 3, 4]
    
    var isRunning: Bool {
        guard let tap = eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }
    
    func start() -> Bool {
        stop()
        
        let eventMask: CGEventMask = (
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.keyDown.rawValue)
        )
        
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
        
        // Permettre l'annulation avec la touche Échap (53) ou un clic gauche quand le menu est ouvert
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
                    self?.delegate?.eventTapDidTriggerCommit()
                }
                return nil
            }
        }
        
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let isRightDown = (type == .rightMouseDown)
        let isOtherDown = (type == .otherMouseDown && extraTriggerButtons.contains(buttonNumber))
        
        // 1. INTERCEPTION STRICTE DU CLIC DROIT : ouverture ou fermeture du Pie Menu
        if isRightDown || isOtherDown {
            if isMenuCurrentlyActive {
                isMenuCurrentlyActive = false
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.eventTapDidCancel()
                }
                return nil
            }
            
            isMenuCurrentlyActive = true
            pressTimestamp = ProcessInfo.processInfo.systemUptime
            let cocoaLocation = NSEvent.mouseLocation
            initialPressLocation = cocoaLocation
            didSelectSliceDuringHold = false
            
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.eventTapDidTriggerShow(at: cocoaLocation)
            }
            // Bloque à 100% le menu contextuel natif macOS
            return nil
        }
        
        // 2. MOUVEMENT OU GLISSEMENT DU CURSEUR
        if isMenuCurrentlyActive && (type == .rightMouseDragged || type == .otherMouseDragged || type == .mouseMoved) {
            let cocoaLocation = NSEvent.mouseLocation
            let dist = hypot(cocoaLocation.x - initialPressLocation.x, cocoaLocation.y - initialPressLocation.y)
            if dist >= 38.0 {
                didSelectSliceDuringHold = true
            }
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.eventTapDidMoveCursor(to: cocoaLocation)
            }
            return nil
        }
        
        // 3. RELÂCHEMENT DU CLIC DROIT
        let isRightUp = (type == .rightMouseUp)
        let isOtherUp = (type == .otherMouseUp && extraTriggerButtons.contains(buttonNumber))
        
        if isRightUp || isOtherUp {
            guard isMenuCurrentlyActive else {
                // Avale toujours le rightMouseUp pour que macOS n'ouvre jamais son menu au relâchement
                return nil
            }
            
            let elapsed = ProcessInfo.processInfo.systemUptime - pressTimestamp
            let cgLocation = event.location
            
            // Si l'utilisateur a déjà glissé sur une tranche pendant qu'il maintenait le clic, on exécute au relâchement
            if didSelectSliceDuringHold {
                isMenuCurrentlyActive = false
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.eventTapDidTriggerCommit()
                }
                return nil
            }
            
            // Optionnel : si l'utilisateur a explicitement activé le pass-through du clic droit natif dans les réglages
            if isRightUp && ProfileStore.shared.allowQuickRightClickPassThrough && elapsed < 0.18 {
                isMenuCurrentlyActive = false
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.eventTapDidCancel()
                    self?.postNativeRightClick(at: cgLocation)
                }
                return nil
            }
            
            // Si l'utilisateur a fait un simple clic droit sans bouger : on laisse le Pie Menu ouvert !
            // Il peut maintenant simplement glisser son curseur sur l'option voulue sans maintenir le bouton.
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