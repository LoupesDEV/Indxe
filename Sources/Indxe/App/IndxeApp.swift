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
                
                Divider()
                
                Text("Déclencheur : Clic Milieu, Boutons Souris 4/5 ou ⌥ + Clic Droit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
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