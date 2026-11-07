import Foundation
import CoreGraphics
import AppKit

enum ActionExecutor {
    static func execute(_ slice: RadialSlice) {
        switch slice.payload {
        case let .keyShortcut(keyCode, flags):
            postKeyStroke(keyCode: keyCode, flags: flags)
        case let .shellCommand(command):
            runShellCommand(command)
        case let .appleScript(source):
            runAppleScript(source)
        case let .custom(handler):
            handler()
        }
    }
    
    private static func postKeyStroke(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        
        keyDown.flags = flags
        keyUp.flags = flags
        
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
    
    private static func runShellCommand(_ command: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            try? process.run()
        }
    }
    
    private static func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let script = NSAppleScript(source: source) {
                script.executeAndReturnError(&error)
            }
        }
    }
}