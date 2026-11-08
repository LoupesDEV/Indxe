import Foundation
import AppKit
import Observation
import Carbon.HIToolbox

@Observable
final class ProfileStore {
    static let shared = ProfileStore()
    
    var profiles: [AppProfile] = []
    
    var selectedTheme: RingTheme = .cyrexCrimson {
        didSet { UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme") }
    }
    
    var instantHoverTrigger: Bool = true {
        didSet { UserDefaults.standard.set(instantHoverTrigger, forKey: "instantHoverTrigger") }
    }
    
    var allowQuickRightClickPassThrough: Bool = false {
        didSet { UserDefaults.standard.set(allowQuickRightClickPassThrough, forKey: "allowQuickRightClickPassThrough") }
    }
    
    private let storageURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("Indxe", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.storageURL = folder.appendingPathComponent("profiles.json")
        
        if let rawTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = RingTheme(rawValue: rawTheme) {
            self.selectedTheme = theme
        }
        if UserDefaults.standard.object(forKey: "allowQuickRightClickPassThrough") != nil {
            self.allowQuickRightClickPassThrough = UserDefaults.standard.bool(forKey: "allowQuickRightClickPassThrough")
        }
        if UserDefaults.standard.object(forKey: "instantHoverTrigger") != nil {
            self.instantHoverTrigger = UserDefaults.standard.bool(forKey: "instantHoverTrigger")
        }
        
        load()
    }
    
    func load() {
        if let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode([AppProfile].self, from: data),
           !decoded.isEmpty {
            var normalizedProfiles = decoded
            if let globalIndex = normalizedProfiles.firstIndex(where: { $0.bundleIdentifier == AppProfile.globalBundleID }),
               normalizedProfiles[globalIndex].displayName != "Global" {
                normalizedProfiles[globalIndex].displayName = "Global"
                self.profiles = normalizedProfiles
                save()
            } else {
                self.profiles = normalizedProfiles
            }
            mergeMissingDefaultProfiles()
        } else {
            self.profiles = Self.defaultSeedProfiles()
            save()
        }
    }
    
    /// Ajoute les nouveaux profils par défaut qui n'existeraient pas encore dans le JSON de l'utilisateur
    func mergeMissingDefaultProfiles() {
        var didChange = false
        if !profiles.contains(where: { $0.bundleIdentifier == AppProfile.globalBundleID }) {
            profiles.insert(Self.defaultGlobalProfile, at: 0)
            didChange = true
        }
        for seed in Self.defaultSeedProfiles() {
            if !profiles.contains(where: { $0.bundleIdentifier == seed.bundleIdentifier }) {
                profiles.append(seed)
                didChange = true
            }
        }
        if didChange {
            save()
        }
    }
    
    /// Réinitialise tous les profils d'usine
    func restoreFactoryDefaults() {
        self.profiles = Self.defaultSeedProfiles()
        save()
    }
    
    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(profiles) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
    
    func profile(for bundleIdentifier: String?, appName: String?) -> AppProfile {
        if let bundleId = bundleIdentifier,
           let matched = profiles.first(where: { $0.bundleIdentifier == bundleId }) {
            return matched
        }
        let global = profiles.first(where: { $0.bundleIdentifier == AppProfile.globalBundleID }) ?? Self.defaultGlobalProfile
        return AppProfile(
            bundleIdentifier: bundleIdentifier ?? AppProfile.globalBundleID,
            displayName: appName ?? global.displayName,
            appPath: nil,
            slices: global.slices
        )
    }
    
    func addOrSelectApplication(url: URL) -> AppProfile? {
        guard let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier else { return nil }
        
        if let existing = profiles.first(where: { $0.bundleIdentifier == bundleId }) {
            return existing
        }
        
        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        
        let globalSlices = profiles.first(where: { $0.bundleIdentifier == AppProfile.globalBundleID })?.slices ?? []
        let newProfile = AppProfile(
            bundleIdentifier: bundleId,
            displayName: name,
            appPath: url.path,
            slices: globalSlices
        )
        profiles.append(newProfile)
        save()
        return newProfile
    }
    
    func removeProfile(bundleIdentifier: String) {
        guard bundleIdentifier != AppProfile.globalBundleID else { return }
        profiles.removeAll { $0.bundleIdentifier == bundleIdentifier }
        save()
    }
    
    // MARK: - Catalogue de Profils par Défaut
    
    static let defaultGlobalProfile = AppProfile(
        bundleIdentifier: AppProfile.globalBundleID,
        displayName: "Global",
        appPath: nil,
        slices: [
            RadialSlice(title: "Copier", systemImage: "doc.on.doc.fill", accentColorHex: 0x3B82F6,
                        payload: .shortcut(keyCode: kVK_ANSI_C, flags: .maskCommand)),
            RadialSlice(title: "Coller", systemImage: "doc.on.clipboard.fill", accentColorHex: 0x10B981,
                        payload: .shortcut(keyCode: kVK_ANSI_V, flags: .maskCommand)),
            RadialSlice(title: "Capture Zone", systemImage: "camera.viewfinder", accentColorHex: 0xF59E0B,
                        payload: .shortcut(keyCode: kVK_ANSI_4, flags: [.maskCommand, .maskShift])),
            RadialSlice(title: "Mission Ctrl", systemImage: "macwindow.on.rectangle", accentColorHex: 0x8B5CF6,
                        payload: .shortcut(keyCode: kVK_UpArrow, flags: .maskControl)),
            RadialSlice(title: "Annuler", systemImage: "arrow.uturn.backward.circle.fill", accentColorHex: 0xEF4444,
                        payload: .shortcut(keyCode: kVK_ANSI_Z, flags: .maskCommand)),
            RadialSlice(title: "Spotlight", systemImage: "sparkle.magnifyingglass", accentColorHex: 0xDC2626,
                        payload: .shortcut(keyCode: kVK_Space, flags: .maskCommand))
        ]
    )
    
    static func defaultSeedProfiles() -> [AppProfile] {
        [
            defaultGlobalProfile,
            
            // Finder
            AppProfile(
                bundleIdentifier: "com.apple.finder",
                displayName: "Finder",
                appPath: "/System/Library/CoreServices/Finder.app",
                slices: [
                    RadialSlice(title: "Nouv. Dossier", systemImage: "folder.badge.plus", accentColorHex: 0x3B82F6,
                                payload: .shortcut(keyCode: kVK_ANSI_N, flags: [.maskCommand, .maskShift])),
                    RadialSlice(title: "Infos", systemImage: "info.circle.fill", accentColorHex: 0x06B6D4,
                                payload: .shortcut(keyCode: kVK_ANSI_I, flags: .maskCommand)),
                    RadialSlice(title: "Aller au dossier", systemImage: "arrow.right.doc.on.clipboard", accentColorHex: 0xF59E0B,
                                payload: .shortcut(keyCode: kVK_ANSI_G, flags: [.maskCommand, .maskShift])),
                    RadialSlice(title: "Corbeille", systemImage: "trash.fill", accentColorHex: 0xEF4444,
                                payload: .shortcut(keyCode: kVK_Delete, flags: .maskCommand)),
                    RadialSlice(title: "Dupliquer", systemImage: "plus.square.on.square", accentColorHex: 0x10B981,
                                payload: .shortcut(keyCode: kVK_ANSI_D, flags: .maskCommand)),
                    RadialSlice(title: "Fichiers Cachés", systemImage: "eye.slash.fill", accentColorHex: 0x8B5CF6,
                                payload: .shortcut(keyCode: kVK_ANSI_Period, flags: [.maskCommand, .maskShift]))
                ]
            ),

            // VS Code
            AppProfile(
                bundleIdentifier: "com.microsoft.VSCode",
                displayName: "VS Code",
                appPath: "/Applications/Visual Studio Code.app",
                slices: [
                    RadialSlice(title: "Palette Cmd", systemImage: "command", accentColorHex: 0xDC2626,
                                payload: .shortcut(keyCode: kVK_ANSI_P, flags: [.maskCommand, .maskShift])),
                    RadialSlice(title: "Terminal", systemImage: "apple.terminal", accentColorHex: 0x3B82F6,
                                payload: .shortcut(keyCode: kVK_ANSI_Grave, flags: .maskControl)),
                    RadialSlice(title: "Chercher Global", systemImage: "doc.text.magnifyingglass", accentColorHex: 0xF59E0B,
                                payload: .shortcut(keyCode: kVK_ANSI_F, flags: [.maskCommand, .maskShift])),
                    RadialSlice(title: "Split Éditeur", systemImage: "rectangle.split.2x1", accentColorHex: 0x10B981,
                                payload: .shortcut(keyCode: kVK_ANSI_Backslash, flags: .maskCommand)),
                    RadialSlice(title: "Sidebar", systemImage: "sidebar.left", accentColorHex: 0x8B5CF6,
                                payload: .shortcut(keyCode: kVK_ANSI_B, flags: .maskCommand)),
                    RadialSlice(title: "Fermer Onglet", systemImage: "xmark.square", accentColorHex: 0xEF4444,
                                payload: .shortcut(keyCode: kVK_ANSI_W, flags: .maskCommand))
                ]
            ),
            
            // 4. Safari
            AppProfile(
                bundleIdentifier: "com.apple.Safari",
                displayName: "Safari",
                appPath: "/Applications/Safari.app",
                slices: [
                    RadialSlice(title: "Nouvel Onglet", systemImage: "plus.square.on.square", accentColorHex: 0x3B82F6,
                                payload: .shortcut(keyCode: kVK_ANSI_T, flags: .maskCommand)),
                    RadialSlice(title: "Onglet Suiv.", systemImage: "arrow.right.square", accentColorHex: 0x10B981,
                                payload: .shortcut(keyCode: kVK_Tab, flags: .maskControl)),
                    RadialSlice(title: "Actualiser", systemImage: "arrow.clockwise", accentColorHex: 0xF59E0B,
                                payload: .shortcut(keyCode: kVK_ANSI_R, flags: .maskCommand)),
                    RadialSlice(title: "Fermer Onglet", systemImage: "xmark", accentColorHex: 0xEF4444,
                                payload: .shortcut(keyCode: kVK_ANSI_W, flags: .maskCommand)),
                    RadialSlice(title: "Inspecteur Web", systemImage: "chevron.left.forwardslash.chevron.right", accentColorHex: 0xDC2626,
                                payload: .shortcut(keyCode: kVK_ANSI_I, flags: [.maskCommand, .maskAlternate])),
                    RadialSlice(title: "Onglet Préc.", systemImage: "arrow.left.square", accentColorHex: 0x8B5CF6,
                                payload: .shortcut(keyCode: kVK_Tab, flags: [.maskControl, .maskShift]))
                ]
            ),
            
            // Terminal macOS
            AppProfile(
                bundleIdentifier: "com.apple.Terminal",
                displayName: "Terminal",
                appPath: "/System/Applications/Utilities/Terminal.app",
                slices: [
                    RadialSlice(title: "Nouvel Onglet", systemImage: "plus.rectangle.on.rectangle", accentColorHex: 0x10B981,
                                payload: .shortcut(keyCode: kVK_ANSI_T, flags: .maskCommand)),
                    RadialSlice(title: "Clear", systemImage: "sparkles", accentColorHex: 0x3B82F6,
                                payload: .shortcut(keyCode: kVK_ANSI_K, flags: .maskCommand)),
                    RadialSlice(title: "Split Pane", systemImage: "rectangle.split.1x2", accentColorHex: 0xF59E0B,
                                payload: .shortcut(keyCode: kVK_ANSI_D, flags: .maskCommand)),
                    RadialSlice(title: "Stop (Ctrl+C)", systemImage: "stop.circle.fill", accentColorHex: 0xEF4444,
                                payload: .shortcut(keyCode: kVK_ANSI_C, flags: .maskControl)),
                    RadialSlice(title: "Rechercher", systemImage: "magnifyingglass", accentColorHex: 0x8B5CF6,
                                payload: .shortcut(keyCode: kVK_ANSI_F, flags: .maskCommand)),
                    RadialSlice(title: "Fermer", systemImage: "xmark", accentColorHex: 0xDC2626,
                                payload: .shortcut(keyCode: kVK_ANSI_W, flags: .maskCommand))
                ]
            ),
            
            // Spotify
            AppProfile(
                bundleIdentifier: "com.spotify.client",
                displayName: "Spotify",
                appPath: "/Applications/Spotify.app",
                slices: [
                    RadialSlice(title: "Play / Pause", systemImage: "playpause.fill", accentColorHex: 0x10B981,
                                payload: .shortcut(keyCode: kVK_Space, flags: [])),
                    RadialSlice(title: "Suivant", systemImage: "forward.end.fill", accentColorHex: 0x3B82F6,
                                payload: .shortcut(keyCode: kVK_RightArrow, flags: .maskCommand)),
                    RadialSlice(title: "Volume +", systemImage: "speaker.wave.3.fill", accentColorHex: 0xF59E0B,
                                payload: .shortcut(keyCode: kVK_UpArrow, flags: .maskCommand)),
                    RadialSlice(title: "Volume -", systemImage: "speaker.wave.1.fill", accentColorHex: 0x8B5CF6,
                                payload: .shortcut(keyCode: kVK_DownArrow, flags: .maskCommand)),
                    RadialSlice(title: "Précédent", systemImage: "backward.end.fill", accentColorHex: 0xEC4899,
                                payload: .shortcut(keyCode: kVK_LeftArrow, flags: .maskCommand)),
                    RadialSlice(title: "Rechercher", systemImage: "magnifyingglass", accentColorHex: 0x14B8A6,
                                payload: .shortcut(keyCode: kVK_ANSI_L, flags: .maskCommand))
                ]
            ),
            
            // Discord
            AppProfile(
                bundleIdentifier: "com.hnc.Discord",
                displayName: "Discord",
                appPath: "/Applications/Discord.app",
                slices: [
                    RadialSlice(title: "Mute Micro", systemImage: "mic.slash.fill", accentColorHex: 0xEF4444,
                                payload: .shortcut(keyCode: kVK_ANSI_M, flags: [.maskCommand, .maskShift])),
                    RadialSlice(title: "Casque Sourd.", systemImage: "speaker.slash.fill", accentColorHex: 0xDC2626,
                                payload: .shortcut(keyCode: kVK_ANSI_D, flags: [.maskCommand, .maskShift])),
                    RadialSlice(title: "Quick Switcher", systemImage: "magnifyingglass", accentColorHex: 0x5865F2,
                                payload: .shortcut(keyCode: kVK_ANSI_K, flags: .maskCommand)),
                    RadialSlice(title: "Marquer Lu", systemImage: "checkmark.circle.fill", accentColorHex: 0x10B981,
                                payload: .shortcut(keyCode: kVK_Escape, flags: .maskShift)),
                    RadialSlice(title: "Émojis", systemImage: "face.smiling.fill", accentColorHex: 0xF59E0B,
                                payload: .shortcut(keyCode: kVK_ANSI_E, flags: .maskCommand))
                ]
            ),

            // Deezer
            AppProfile(
                bundleIdentifier: "com.deezer.Deezer",
                displayName: "Deezer",
                appPath: "/Applications/Deezer.app",
                slices: [
                    RadialSlice(title: "Play / Pause", systemImage: "playpause.fill", accentColorHex: 0x10B981,
                                payload: .shortcut(keyCode: kVK_Space, flags: [])),
                    RadialSlice(title: "Suivant", systemImage: "forward.end.fill", accentColorHex: 0x3B82F6,
                                payload: .shortcut(keyCode: kVK_RightArrow, flags: .maskCommand)),
                    RadialSlice(title: "Volume +", systemImage: "speaker.wave.3.fill", accentColorHex: 0xF59E0B,
                                payload: .shortcut(keyCode: kVK_UpArrow, flags: .maskCommand)),
                    RadialSlice(title: "Volume -", systemImage: "speaker.wave.1.fill", accentColorHex: 0x8B5CF6,
                                payload: .shortcut(keyCode: kVK_DownArrow, flags: .maskCommand)),
                    RadialSlice(title: "Précédent", systemImage: "backward.end.fill", accentColorHex: 0xEC4899,
                                payload: .shortcut(keyCode: kVK_LeftArrow, flags: .maskCommand)),
                    RadialSlice(title: "Rechercher", systemImage: "magnifyingglass", accentColorHex: 0x14B8A6,
                                payload: .shortcut(keyCode: kVK_ANSI_L, flags: .maskCommand))
                ]
            )
        ]
    }
}