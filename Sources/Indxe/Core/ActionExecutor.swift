import Foundation
import CoreGraphics
import AppKit
import Carbon.HIToolbox

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
            
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
                return
            }
            
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
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        
        let terminalBundles: Set<String> = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "dev.warp.Warp-Stable",
            "com.mitchellh.ghostty",
            "net.kovidgoyal.kitty"
        ]
        
        if let bundleID = frontBundleID, terminalBundles.contains(bundleID) {
            typeCommandIntoActiveTerminal(trimmed)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-ic", trimmed]
            try? process.run()
        }
    }
    
    private static func typeCommandIntoActiveTerminal(_ command: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
            
            let utf16Chars = Array(command.utf16)
            if let textDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
               let textUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                textDown.flags = []
                textUp.flags = []
                textDown.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
                textUp.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
                textDown.post(tap: .cgSessionEventTap)
                textUp.post(tap: .cgSessionEventTap)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                guard let enterDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Return), keyDown: true),
                      let enterUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Return), keyDown: false) else {
                    return
                }
                enterDown.flags = []
                enterUp.flags = []
                enterDown.post(tap: .cgSessionEventTap)
                enterUp.post(tap: .cgSessionEventTap)
            }
        }
    }
    
    private static func runAppleScript(_ source: String) {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let script = NSAppleScript(source: trimmed) {
                script.executeAndReturnError(&error)
            }
        }
    }
}