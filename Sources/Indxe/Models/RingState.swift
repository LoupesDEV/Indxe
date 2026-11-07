import Foundation
import AppKit
import CoreGraphics
import Observation

@Observable
final class RingState {
    var isVisible: Bool = false
    var centerScreenPoint: CGPoint = .zero
    var currentMouseScreenPoint: CGPoint = .zero
    var activeProfile: AppProfile = ProfileStore.defaultGlobalProfile
    var selectedIndex: Int? = nil
    
    let deadZoneRadius: CGFloat = 38.0
    let outerRadius: CGFloat = 135.0
    /// Rayon au-delà duquel le mode "Exécution instantanée au survol" valide automatiquement l'option
    let instantTriggerRadius: CGFloat = 82.0
    
    var currentDistance: CGFloat {
        let dx = currentMouseScreenPoint.x - centerScreenPoint.x
        let dy = currentMouseScreenPoint.y - centerScreenPoint.y
        return hypot(dx, dy)
    }
    
    var currentAngleDegrees: Double? {
        guard currentDistance >= deadZoneRadius else { return nil }
        let dx = currentMouseScreenPoint.x - centerScreenPoint.x
        let dy = -(currentMouseScreenPoint.y - centerScreenPoint.y)
        
        let radians = atan2(dy, dx)
        var degrees = radians * 180.0 / .pi
        degrees += 90.0
        if degrees < 0 {
            degrees += 360.0
        }
        return degrees
    }
    
    /// Met à jour l'angle et retourne `true` si l'exécution instantanée au glissement doit être déclenchée
    @discardableResult
    func updateCursorPosition(_ screenPoint: CGPoint) -> Bool {
        self.currentMouseScreenPoint = screenPoint
        
        let sliceCount = activeProfile.slices.count
        guard sliceCount > 0 else {
            self.selectedIndex = nil
            return false
        }
        
        guard let angle = currentAngleDegrees else {
            self.selectedIndex = nil
            return false
        }
        
        let sectorAngle = 360.0 / Double(sliceCount)
        let shiftedAngle = (angle + (sectorAngle / 2.0)).truncatingRemainder(dividingBy: 360.0)
        let computedIndex = Int(floor(shiftedAngle / sectorAngle)) % sliceCount
        
        if self.selectedIndex != computedIndex {
            self.selectedIndex = computedIndex
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        
        if ProfileStore.shared.instantHoverTrigger && currentDistance >= instantTriggerRadius {
            return true
        }
        return false
    }
}