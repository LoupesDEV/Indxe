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
    fileprivate var didLeaveDeadZoneDuringSession: Bool = false
    
    /// Signature apposée sur les clics droits synthétiques ré-injectés pour éviter toute boucle infinie
    private let syntheticEventTag: Int64 = 0x494E4458 // "INDX"
    
    /// Boutons additionnels (2 = Milieu, 3/4 = Latéraux) en plus du Clic Droit
    var extraTriggerButtons: Set<Int64> = [2, 3, 4]
    
    func start() -> Bool {
        let eventMask: CGEventMask = (
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue)
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
        return true
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
    }
    
    /// Ferme la session depuis le moteur UI (ex: en mode exécution instantanée au survol)
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
        
        // Laisse passer nos propres clics droits synthétiques (Pass-through)
        if event.getIntegerValueField(.eventSourceUserData) == syntheticEventTag {
            return Unmanaged.passUnretained(event)
        }
        
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        
        // Ne pas intercepter le clic droit si la fenêtre de configuration d'Indxe est au premier plan
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return Unmanaged.passUnretained(event)
        }
        
        let isRightDown = (type == .rightMouseDown)
        let isOtherDown = (type == .otherMouseDown && extraTriggerButtons.contains(buttonNumber))
        
        // 1. OUVERTURE DU PIE MENU AU CLIC DROIT (sans afficher le menu natif)
        if isRightDown || isOtherDown {
            isMenuCurrentlyActive = true
            pressTimestamp = ProcessInfo.processInfo.systemUptime
            let cocoaLocation = NSEvent.mouseLocation
            initialPressLocation = cocoaLocation
            didLeaveDeadZoneDuringSession = false
            
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.eventTapDidTriggerShow(at: cocoaLocation)
            }
            // Retourner nil avale l'événement et bloque à 100% le menu contextuel par défaut
            return nil
        }
        
        // 2. GLISSEMENT DU CURSEUR VERS L'OPTION VOULUE
        if isMenuCurrentlyActive && (type == .rightMouseDragged || type == .otherMouseDragged || type == .mouseMoved) {
            let cocoaLocation = NSEvent.mouseLocation
            let dist = hypot(cocoaLocation.x - initialPressLocation.x, cocoaLocation.y - initialPressLocation.y)
            if dist > 25.0 {
                didLeaveDeadZoneDuringSession = true
            }
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.eventTapDidMoveCursor(to: cocoaLocation)
            }
            return nil
        }
        
        // 3. RELÂCHEMENT DU BOUTON : EXÉCUTION IMMÉDIATE DE LA TRANCHE SURVOLÉE
        let isRightUp = (type == .rightMouseUp)
        let isOtherUp = (type == .otherMouseUp && extraTriggerButtons.contains(buttonNumber))
        
        if isRightUp || isOtherUp {
            guard isMenuCurrentlyActive else {
                // Si la session a déjà été consommée par le mode Instant-Hover, on avale simplement le MouseUp
                return nil
            }
            
            isMenuCurrentlyActive = false
            let elapsed = ProcessInfo.processInfo.systemUptime - pressTimestamp
            let cgLocation = event.location
            
            // Si clic droit très court (< 180ms) sans glisser hors du centre et que l'option pass-through est active :
            // on ferme l'anneau et on déclenche le vrai clic droit macOS.
            if isRightUp && ProfileStore.shared.allowQuickRightClickPassThrough && elapsed < 0.18 && !didLeaveDeadZoneDuringSession {
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.eventTapDidCancel()
                    self?.postNativeRightClick(at: cgLocation)
                }
                return nil
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.eventTapDidTriggerCommit()
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