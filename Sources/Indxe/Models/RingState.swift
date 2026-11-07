import Foundation
import AppKit
import CoreGraphics
import Observation

@Observable
final class RingState {
    var isVisible: Bool = false
    var centerScreenPoint: CGPoint = .zero
    var currentMouseScreenPoint: CGPoint = .zero
    var activeProfile: AppProfile = ContextResolver.defaultProfile
    var selectedIndex: Int? = nil
    
    /// Rayon en dessous duquel aucun secteur n'est sélectionné (zone d'annulation)
    let deadZoneRadius: CGFloat = 38.0
    /// Rayon extérieur de l'anneau
    let outerRadius: CGFloat = 135.0
    
    /// Distance euclidienne actuelle du curseur par rapport au centre d'invocation
    var currentDistance: CGFloat {
        let dx = currentMouseScreenPoint.x - centerScreenPoint.x
        let dy = currentMouseScreenPoint.y - centerScreenPoint.y
        return hypot(dx, dy)
    }
    
    /// Angle courant du curseur en degrés [0°, 360°[ avec 0° à 12 heures (sens horaire)
    var currentAngleDegrees: Double? {
        guard currentDistance >= deadZoneRadius else { return nil }
        let dx = currentMouseScreenPoint.x - centerScreenPoint.x
        // Dans le repère global NSScreen, Y pointe vers le haut.
        // Pour un sens horaire avec 0° en haut (12h), on inverse Y pour le calcul standard.
        let dy = -(currentMouseScreenPoint.y - centerScreenPoint.y)
        
        let radians = atan2(dy, dx)
        var degrees = radians * 180.0 / .pi
        
        // Décalage de +90° pour ramener l'origine (0°) de l'Est (3h) vers le Nord (12h)
        degrees += 90.0
        if degrees < 0 {
            degrees += 360.0
        }
        return degrees
    }
    
    /// Met à jour la position du curseur et recalcule la tranche active par trigonométrie
    func updateCursorPosition(_ screenPoint: CGPoint) {
        self.currentMouseScreenPoint = screenPoint
        
        let sliceCount = activeProfile.slices.count
        guard sliceCount > 0 else {
            self.selectedIndex = nil
            return
        }
        
        guard let angle = currentAngleDegrees else {
            self.selectedIndex = nil
            return
        }
        
        let sectorAngle = 360.0 / Double(sliceCount)
        // Décalage d'un demi-secteur pour que la tranche 0 soit centrée sur 0° (12h)
        let shiftedAngle = (angle + (sectorAngle / 2.0)).truncatingRemainder(dividingBy: 360.0)
        let computedIndex = Int(floor(shiftedAngle / sectorAngle)) % sliceCount
        
        if self.selectedIndex != computedIndex {
            self.selectedIndex = computedIndex
            // Retour haptique léger sur les trackpads Force Touch compatibles
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }
}