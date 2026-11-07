import AppKit

final class ContextResolver {
    static let shared = ContextResolver()
    
    private init() {}
    
    func resolveCurrentProfile() -> AppProfile {
        let frontApp = NSWorkspace.shared.frontmostApplication
        return ProfileStore.shared.profile(
            for: frontApp?.bundleIdentifier,
            appName: frontApp?.localizedName
        )
    }
}