import Foundation
import AppKit
import CoreGraphics

enum ActionPayload {
    case keyShortcut(keyCode: CGKeyCode, flags: CGEventFlags)
    case shellCommand(String)
    case appleScript(String)
    case custom(() -> Void)
}

struct RadialSlice: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let accentColorHex: UInt32
    let payload: ActionPayload
}

struct AppProfile {
    let bundleIdentifier: String
    let displayName: String
    let slices: [RadialSlice]
}