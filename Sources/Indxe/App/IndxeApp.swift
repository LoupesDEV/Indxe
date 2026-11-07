import SwiftUI
import AppKit

@main
struct IndxeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Indxe", systemImage: "circle.hexagongrid.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Indxe — Actions Ring")
                    .font(.headline)
                
                Text("Clic Droit + Glisser → Relâcher sur l'option")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Divider()
                
                Button("Configurer les Applications et Menus...") {
                    appDelegate.openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: [.command])
                
                Divider()
                
                Button("Ouvrir les réglages d'Accessibilité...") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Button("Relancer l'écoute matérielle (EventTap)") {
                    appDelegate.eventTapManager.stop()
                    appDelegate.checkPermissionsAndStartTap()
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