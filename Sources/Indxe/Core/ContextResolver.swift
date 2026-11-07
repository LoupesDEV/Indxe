import AppKit
import Carbon.HIToolbox

final class ContextResolver {
    static let shared = ContextResolver()
    
    private var profiles: [String: AppProfile] = [:]
    
    private init() {
        registerBuiltInProfiles()
    }
    
    /// Résout dynamiquement le profil correspondant à l'application ayant le focus
    func resolveCurrentProfile() -> AppProfile {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else {
            return Self.defaultProfile
        }
        
        if let matchedProfile = profiles[bundleId] {
            return matchedProfile
        }
        
        return AppProfile(
            bundleIdentifier: bundleId,
            displayName: frontApp.localizedName ?? "Système",
            slices: Self.defaultProfile.slices
        )
    }
    
    private func registerBuiltInProfiles() {
        // Profil Xcode
        profiles["com.apple.dt.Xcode"] = AppProfile(
            bundleIdentifier: "com.apple.dt.Xcode",
            displayName: "Xcode",
            slices: [
                RadialSlice(title: "Build", systemImage: "hammer.fill", accentColorHex: 0x3B82F6,
                            payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_B), flags: .maskCommand)),
                RadialSlice(title: "Run", systemImage: "play.fill", accentColorHex: 0x10B981,
                            payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_R), flags: .maskCommand)),
                RadialSlice(title: "Clean", systemImage: "trash.fill", accentColorHex: 0xEF4444,
                            payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_K), flags: [.maskCommand, .maskShift])),
                RadialSlice(title: "Open Quickly", systemImage: "magnifyingglass", accentColorHex: 0xF59E0B,
                            payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_O), flags: [.maskCommand, .maskShift])),
                RadialSlice(title: "Show Console", systemImage: "terminal.fill", accentColorHex: 0x8B5CF6,
                            payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_Y), flags: [.maskCommand, .maskShift])),
                RadialSlice(title: "Format", systemImage: "text.alignleft", accentColorHex: 0xEC4899,
                            payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_I), flags: .maskControl))
            ]
        )
        
        // Profil VS Code / JetBrains / Éditeurs
        let codeSlices: [RadialSlice] = [
            RadialSlice(title: "Palette", systemImage: "command", accentColorHex: 0xDC2626,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_P), flags: [.maskCommand, .maskShift])),
            RadialSlice(title: "Terminal", systemImage: "apple.terminal", accentColorHex: 0x3B82F6,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_Grave), flags: .maskControl)),
            RadialSlice(title: "Rechercher", systemImage: "doc.text.magnifyingglass", accentColorHex: 0xF59E0B,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_F), flags: [.maskCommand, .maskShift])),
            RadialSlice(title: "Split Éditeur", systemImage: "rectangle.split.2x1", accentColorHex: 0x10B981,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_Backslash), flags: .maskCommand)),
            RadialSlice(title: "Fermer Onglet", systemImage: "xmark.square", accentColorHex: 0xEF4444,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_W), flags: .maskCommand)),
            RadialSlice(title: "Settings", systemImage: "gearshape.fill", accentColorHex: 0x6366F1,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_Comma), flags: .maskCommand))
        ]
        
        profiles["com.microsoft.VSCode"] = AppProfile(
            bundleIdentifier: "com.microsoft.VSCode",
            displayName: "VS Code",
            slices: codeSlices
        )
        
        // Profil Navigateurs (Safari, Arc, Chrome)
        let browserSlices: [RadialSlice] = [
            RadialSlice(title: "Nouvel Onglet", systemImage: "plus.square.on.square", accentColorHex: 0x3B82F6,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_T), flags: .maskCommand)),
            RadialSlice(title: "Onglet Suiv.", systemImage: "arrow.right.square", accentColorHex: 0x10B981,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_Tab), flags: .maskControl)),
            RadialSlice(title: "Actualiser", systemImage: "arrow.clockwise", accentColorHex: 0xF59E0B,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_R), flags: .maskCommand)),
            RadialSlice(title: "Fermer Onglet", systemImage: "xmark", accentColorHex: 0xEF4444,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_W), flags: .maskCommand)),
            RadialSlice(title: "Rouvrir", systemImage: "arrow.uturn.backward", accentColorHex: 0x8B5CF6,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_T), flags: [.maskCommand, .maskShift])),
            RadialSlice(title: "Onglet Préc.", systemImage: "arrow.left.square", accentColorHex: 0x14B8A6,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_Tab), flags: [.maskControl, .maskShift]))
        ]
        
        for id in ["com.apple.Safari", "company.thebrowser.Browser", "com.google.Chrome"] {
            profiles[id] = AppProfile(bundleIdentifier: id, displayName: "Navigateur", slices: browserSlices)
        }
    }
    
    static let defaultProfile = AppProfile(
        bundleIdentifier: "com.apple.system",
        displayName: "Global macOS",
        slices: [
            RadialSlice(title: "Copier", systemImage: "doc.on.doc.fill", accentColorHex: 0x3B82F6,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_C), flags: .maskCommand)),
            RadialSlice(title: "Coller", systemImage: "doc.on.clipboard.fill", accentColorHex: 0x10B981,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)),
            RadialSlice(title: "Capture", systemImage: "camera.viewfinder", accentColorHex: 0xF59E0B,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_4), flags: [.maskCommand, .maskShift])),
            RadialSlice(title: "Mission Ctrl", systemImage: "macwindow.on.rectangle", accentColorHex: 0x8B5CF6,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_UpArrow), flags: .maskControl)),
            RadialSlice(title: "Annuler", systemImage: "arrow.uturn.backward.circle.fill", accentColorHex: 0xEF4444,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_ANSI_Z), flags: .maskCommand)),
            RadialSlice(title: "Spotlight", systemImage: "sparkle.magnifyingglass", accentColorHex: 0xDC2626,
                        payload: .keyShortcut(keyCode: CGKeyCode(kVK_Space), flags: .maskCommand))
        ]
    )
}