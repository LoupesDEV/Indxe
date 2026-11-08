import SwiftUI
import AppKit

@main
struct IndxeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Indxe", systemImage: appDelegate.isTapActive ? "circle.hexagongrid.fill" : "exclamationmark.triangle.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Indxe — Actions Ring")
                    .font(.headline)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(appDelegate.isTapActive ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(appDelegate.isTapActive
                         ? "Statut : Actif (Clic droit intercepté)"
                         : "Statut : Bloqué par macOS (Accessibilité)")
                        .font(.caption)
                }
                
                Divider()
                
                Button("Configurer les Applications et Menus...") {
                    appDelegate.openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: [.command])
                
                Divider()
                
                if !appDelegate.isTapActive {
                    Button("Réparer l'autorisation Accessibilité (Recommandé après un build)") {
                        appDelegate.resetTCCPermissions()
                    }
                }
                
                Button("Ouvrir les réglages d'Accessibilité...") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Button("Relancer l'écoute matérielle (EventTap)") {
                    appDelegate.checkPermissionsAndStartTap(promptIfNeeded: true)
                }
                
                Divider()
                
                Button("Quitter Indxe") {
                    appDelegate.eventTapManager.stop()
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
            .padding(6)
        }
    }
}