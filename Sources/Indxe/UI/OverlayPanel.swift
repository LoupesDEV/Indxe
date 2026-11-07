import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    init(contentRect: NSRect, rootView: some View) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true // Le pilotage s'effectue à 100% via le CGEventTap
        self.animationBehavior = .none
        
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = contentRect
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        self.contentView = hostingView
    }
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    /// Positionne le centre exact du NSPanel sur les coordonnées écran du curseur
    func showCentered(at screenPoint: CGPoint) {
        let width = self.frame.width
        let height = self.frame.height
        let origin = CGPoint(
            x: round(screenPoint.x - (width / 2.0)),
            y: round(screenPoint.y - (height / 2.0))
        )
        self.setFrameOrigin(origin)
        self.orderFrontRegardless()
    }
}