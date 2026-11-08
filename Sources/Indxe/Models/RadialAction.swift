import Foundation
import AppKit
import CoreGraphics
import Carbon.HIToolbox

enum RingTheme: String, Codable, CaseIterable, Identifiable {
    case cyrexCrimson = "cyrex_crimson"
    case midnightVanilla = "midnight_vanilla"
    case swissMinimal = "swiss_minimal"
    case terminalMatrix = "terminal_matrix"
    case frostGlass = "frost_glass"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .cyrexCrimson: return "Crimson"
        case .midnightVanilla: return "Midnight"
        case .swissMinimal: return "Amber"
        case .terminalMatrix: return "Emerald"
        case .frostGlass: return "Mono"
        }
    }
    
    var sliceBackgroundHex: UInt32 {
        switch self {
        case .cyrexCrimson: return 0x0D1117
        case .midnightVanilla: return 0x282B4A
        case .swissMinimal: return 0x141413
        case .terminalMatrix: return 0x09110E
        case .frostGlass: return 0x141416
        }
    }
    
    var centerHubHex: UInt32 {
        switch self {
        case .cyrexCrimson: return 0x090C10
        case .midnightVanilla: return 0x1E2038
        case .swissMinimal: return 0x0E0E0D
        case .terminalMatrix: return 0x050907
        case .frostGlass: return 0x0C0C0E
        }
    }
    
    var overrideAccentHex: UInt32? {
        switch self {
        case .cyrexCrimson: return 0xDC2626
        case .midnightVanilla: return 0xEEEBDA
        case .swissMinimal: return 0xEA580C
        case .terminalMatrix: return 0x10B981
        case .frostGlass: return 0xF4F4F5
        }
    }
    
    var primaryTextHex: UInt32 {
        switch self {
        case .midnightVanilla: return 0xEEEBDA
        default: return 0xF4F4F5
        }
    }
    
    var selectedForegroundHex: UInt32 {
        switch self {
        case .midnightVanilla: return 0x1E2038
        case .frostGlass: return 0x09090B
        case .terminalMatrix: return 0x050907
        default: return 0xFFFFFF
        }
    }
    
    var borderOpacity: Double { 0.14 }
    var gapDegrees: Double { 2.0 }
    var ringExpansionOnHover: CGFloat { 5.0 }
}

enum ActionPayloadType: String, Codable, CaseIterable, Identifiable {
    case keyShortcut = "Raccourci"
    case shellCommand = "Shell"
    case appleScript = "Script"
    
    var id: String { rawValue }
}

struct ActionPayload: Codable, Hashable {
    var type: ActionPayloadType
    var keyCode: UInt16
    var modifiersRaw: UInt64
    var scriptOrCommand: String
    
    init(type: ActionPayloadType, keyCode: UInt16, modifiersRaw: UInt64, scriptOrCommand: String) {
        self.type = type
        self.keyCode = keyCode
        self.modifiersRaw = modifiersRaw
        self.scriptOrCommand = scriptOrCommand
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = (try? container.decode(String.self, forKey: .type)) ?? "Raccourci"
        switch rawType {
        case "Raccourci Clavier", "KEYBIND", "Raccourci": self.type = .keyShortcut
        case "Commande Shell", "EXEC ZSH", "Shell": self.type = .shellCommand
        case "AppleScript", "OSASCRIPT", "Script": self.type = .appleScript
        default: self.type = .keyShortcut
        }
        self.keyCode = (try? container.decode(UInt16.self, forKey: .keyCode)) ?? 0
        self.modifiersRaw = (try? container.decode(UInt64.self, forKey: .modifiersRaw)) ?? 0
        self.scriptOrCommand = (try? container.decode(String.self, forKey: .scriptOrCommand)) ?? ""
    }
    
    static func shortcut(keyCode: Int, flags: CGEventFlags) -> ActionPayload {
        ActionPayload(
            type: .keyShortcut,
            keyCode: UInt16(keyCode),
            modifiersRaw: flags.rawValue,
            scriptOrCommand: ""
        )
    }
    
    static func shell(_ cmd: String) -> ActionPayload {
        ActionPayload(type: .shellCommand, keyCode: 0, modifiersRaw: 0, scriptOrCommand: cmd)
    }
    
    static func appleScript(_ script: String) -> ActionPayload {
        ActionPayload(type: .appleScript, keyCode: 0, modifiersRaw: 0, scriptOrCommand: script)
    }
    
    var cgFlags: CGEventFlags {
        CGEventFlags(rawValue: modifiersRaw)
    }
    
    var humanReadableShortcut: String {
        switch type {
        case .keyShortcut:
            var parts: [String] = []
            let flags = cgFlags
            if flags.contains(.maskControl) { parts.append("⌃") }
            if flags.contains(.maskAlternate) { parts.append("⌥") }
            if flags.contains(.maskShift) { parts.append("⇧") }
            if flags.contains(.maskCommand) { parts.append("⌘") }
            parts.append(KeyCodeMapper.string(for: keyCode))
            return parts.joined()
        case .shellCommand:
            return "Shell"
        case .appleScript:
            return "Script"
        }
    }
}

struct RadialSlice: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var systemImage: String
    var accentColorHex: UInt32
    var payload: ActionPayload
}

struct AppProfile: Identifiable, Codable, Hashable {
    var id: String { bundleIdentifier }
    var bundleIdentifier: String
    var displayName: String
    var appPath: String?
    var slices: [RadialSlice]
    
    static let globalBundleID = "com.indxe.global"
}

enum KeyCodeMapper {
    static func string(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Grave: return "`"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default: return "Key(\(keyCode))"
        }
    }
}