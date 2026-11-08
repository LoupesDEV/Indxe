import Foundation
import CoreGraphics
import AppKit

enum ActionExecutor {
    static func execute(_ slice: RadialSlice) {
        let payload = slice.payload
        switch payload.type {
        case .keyShortcut:
            postKeyStroke(keyCode: CGKeyCode(payload.keyCode), flags: payload.cgFlags)
        case .shellCommand:
            runShellCommand(payload.scriptOrCommand)
        case .appleScript:
            runAppleScript(payload.scriptOrCommand)
        }
    }
    
    private static func postKeyStroke(keyCode: CGKeyCode, flags: CGEventFlags) {
        // Léger délai de 20ms pour laisser le NSPanel se fermer complètement et aux boutons souris de se relâcher
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
            
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
                return
            }
            
            // Nettoie tout flag parasite (ex: bouton souris) et applique uniquement les modificateurs voulus
            let cleanMask: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
            let filteredFlags = flags.intersection(cleanMask)
            
            keyDown.flags = filteredFlags
            keyUp.flags = filteredFlags
            
            keyDown.post(tap: .cgSessionEventTap)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.015) {
                keyUp.post(tap: .cgSessionEventTap)
            }
        }
    }
    
    private static func runShellCommand(_ command: String) {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            try? process.run()
        }
    }
    
    private static func runAppleScript(_ source: String) {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let script = NSAppleScript(source: source) {
                script.executeAndReturnError(&error)
            }
        }
    }
}