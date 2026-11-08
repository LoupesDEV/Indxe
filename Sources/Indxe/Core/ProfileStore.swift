import Foundation
import AppKit
import Observation
import Carbon.HIToolbox

@Observable
final class ProfileStore {
    static let shared = ProfileStore()
    
    var profiles: [AppProfile] = []
    
    /// Si activé, exécute l'action dès que le curseur entre dans une tranche sans même attendre de cliquer ou relâcher
    var instantHoverTrigger: Bool = true {
        didSet { UserDefaults.standard.set(instantHoverTrigger, forKey: "instantHoverTrigger") }
    }
    
    /// Désactivé par défaut pour remplacer à 100% le clic droit natif macOS
    var allowQuickRightClickPassThrough: Bool = false {
        didSet { UserDefaults.standard.set(allowQuickRightClickPassThrough, forKey: "allowQuickRightClickPassThrough") }
    }
    
    private let storageURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("Indxe", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.storageURL = folder.appendingPathComponent("profiles.json")
        
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
            self.profiles = decoded
            ensureGlobalProfileExists()
        } else {
            self.profiles = Self.defaultSeedProfiles()
            save()
        }
    }
    
    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(profiles) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
    
    private func ensureGlobalProfileExists() {
        if !profiles.contains(where: { $0.bundleIdentifier == AppProfile.globalBundleID }) {
            profiles.insert(Self.defaultGlobalProfile, at: 0)
            save()
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
    
    func updateProfile(_ updated: AppProfile) {
        if let idx = profiles.firstIndex(where: { $0.bundleIdentifier == updated.bundleIdentifier }) {
            profiles[idx] = updated
            save()
        }
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
    
    static let defaultGlobalProfile = AppProfile(
        bundleIdentifier: AppProfile.globalBundleID,
        displayName: "Global (Toutes les apps)",
        appPath: nil,
        slices: [
            RadialSlice(title: "Copier", systemImage: "doc.on.doc.fill", accentColorHex: 0x3B82F6,
                        payload: .shortcut(keyCode: kVK_ANSI_C, flags: .maskCommand)),
            RadialSlice(title: "Coller", systemImage: "doc.on.clipboard.fill", accentColorHex: 0x10B981,
                        payload: .shortcut(keyCode: kVK_ANSI_V, flags: .maskCommand)),
            RadialSlice(title: "Capture", systemImage: "camera.viewfinder", accentColorHex: 0xF59E0B,
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
            AppProfile(
                bundleIdentifier: "com.apple.dt.Xcode",
                displayName: "Xcode",
                appPath: "/Applications/Xcode.app",
                slices: [
                    RadialSlice(title: "Build", systemImage: "hammer.fill", accentColorHex: 0x3B82F6,
                                payload: .shortcut(keyCode: kVK_ANSI_B, flags: .maskCommand)),
                    RadialSlice(title: "Run", systemImage: "play.fill", accentColorHex: 0x10B981,
                                payload: .shortcut(keyCode: kVK_ANSI_R, flags: .maskCommand)),
                    RadialSlice(title: "Clean", systemImage: "trash.fill", accentColorHex: 0xEF4444,
                                payload: .shortcut(keyCode: kVK_ANSI_K, flags: [.maskCommand, .maskShift])),
                    RadialSlice(title: "Open Quickly", systemImage: "magnifyingglass", accentColorHex: 0xF59E0B,
                                payload: .shortcut(keyCode: kVK_ANSI_O, flags: [.maskCommand, .maskShift])),
                    RadialSlice(title: "Console", systemImage: "terminal.fill", accentColorHex: 0x8B5CF6,
                                payload: .shortcut(keyCode: kVK_ANSI_Y, flags: [.maskCommand, .maskShift])),
                    RadialSlice(title: "Format", systemImage: "text.alignleft", accentColorHex: 0xEC4899,
                                payload: .shortcut(keyCode: kVK_ANSI_I, flags: .maskControl))
                ]
            ),
            AppProfile(
                bundleIdentifier: "com.microsoft.VSCode",
                displayName: "VS Code",
                appPath: "/Applications/Visual Studio Code.app",
                slices: [
                    RadialSlice(title: "Palette", systemImage: "command", accentColorHex: 0xDC2626,
                                payload: .shortcut(keyCode: kVK_ANSI_P, flags: [.maskCommand, .maskShift])),
                    RadialSlice(title: "Terminal", systemImage: "apple.terminal", accentColorHex: 0x3B82F6,
                                payload: .shortcut(keyCode: kVK_ANSI_Grave, flags: .maskControl)),
                    RadialSlice(title: "Rechercher", systemImage: "doc.text.magnifyingglass", accentColorHex: 0xF59E0B,
                                payload: .shortcut(keyCode: kVK_ANSI_F, flags: [.maskCommand, .maskShift])),
                    RadialSlice(title: "Split", systemImage: "rectangle.split.2x1", accentColorHex: 0x10B981,
                                payload: .shortcut(keyCode: kVK_ANSI_Backslash, flags: .maskCommand)),
                    RadialSlice(title: "Fermer", systemImage: "xmark.square", accentColorHex: 0xEF4444,
                                payload: .shortcut(keyCode: kVK_ANSI_W, flags: .maskCommand))
                ]
            ),
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
                    RadialSlice(title: "Onglet Préc.", systemImage: "arrow.left.square", accentColorHex: 0x8B5CF6,
                                payload: .shortcut(keyCode: kVK_Tab, flags: [.maskControl, .maskShift]))
                ]
            )
        ]
    }
}