import Foundation
import CoreGraphics
import AppKit

protocol EventTapDelegate: AnyObject {
    func eventTapDidTriggerShow(at screenPoint: CGPoint)
    func eventTapDidMoveCursor(to screenPoint: CGPoint)
    func eventTapDidTriggerCommit()
}

final class EventTapManager {
    weak var delegate: EventTapDelegate?
    
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    fileprivate var isMenuCurrentlyActive: Bool = false
    
    /// Numéros de boutons de souris déclencheurs (2 = Clic Milieu, 3 = Bouton Latéral Arrière, 4 = Bouton Latéral Avant)
    var triggerMouseButtons: Set<Int64> = [2, 3, 4]
    
    func start() -> Bool {
        let eventMask: CGEventMask = (
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
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
    
    fileprivate func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Réactivation immédiate si le WindowServer coupe le tap par timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let flags = event.flags
        
        // Détection de l'ouverture : Bouton tiers (Milieu / Latéral) OU Option + Clic Droit
        let isOtherTriggerDown = (type == .otherMouseDown && triggerMouseButtons.contains(buttonNumber))
        let isOptionRightClickDown = (type == .rightMouseDown && flags.contains(.maskAlternate))
        
        if isOtherTriggerDown || isOptionRightClickDown {
            isMenuCurrentlyActive = true
            let cocoaLocation = NSEvent.mouseLocation
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.eventTapDidTriggerShow(at: cocoaLocation)
            }
            // Retourne nil pour consommer le clic et empêcher l'application active de le recevoir
            return nil
        }
        
        // Mise à jour trigonométrique pendant le maintien ou le déplacement
        if isMenuCurrentlyActive && (type == .otherMouseDragged || type == .rightMouseDragged || type == .mouseMoved) {
            let cocoaLocation = NSEvent.mouseLocation
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.eventTapDidMoveCursor(to: cocoaLocation)
            }
            return nil
        }
        
        // Détection du relâchement : Validation de la tranche sélectionnée
        let isOtherTriggerUp = (type == .otherMouseUp && triggerMouseButtons.contains(buttonNumber))
        let isRightClickUp = (type == .rightMouseUp && isMenuCurrentlyActive)
        
        if isMenuCurrentlyActive && (isOtherTriggerUp || isRightClickUp) {
            isMenuCurrentlyActive = false
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.eventTapDidTriggerCommit()
            }
            return nil
        }
        
        return Unmanaged.passUnretained(event)
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