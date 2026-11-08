import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var store: ProfileStore
    @State private var selectedProfileID: String = AppProfile.globalBundleID
    @State private var recordingSliceID: UUID? = nil
    @State private var keyMonitor: Any? = nil
    
    private let bgMain = Color(hex: 0x0D1117)
    private let bgSidebar = Color(hex: 0x090C10)
    private let bgField = Color.white.opacity(0.05)
    private let accent = Color(hex: 0xDC2626)
    
    private let symbols: [String] = [
        "command", "hammer.fill", "play.fill", "playpause.fill", "forward.end.fill", "backward.end.fill",
        "trash.fill", "magnifyingglass", "sparkle.magnifyingglass", "terminal.fill", "apple.terminal",
        "doc.on.doc.fill", "doc.on.clipboard.fill", "camera.viewfinder", "macwindow.on.rectangle",
        "arrow.uturn.backward.circle.fill", "plus.square.on.square", "xmark.square", "arrow.clockwise",
        "rectangle.split.2x1", "rectangle.split.1x2", "sidebar.left", "gearshape.fill", "folder.badge.plus",
        "bolt.fill", "eye.slash.fill", "mic.slash.fill", "speaker.slash.fill", "speaker.wave.3.fill",
        "chevron.left.forwardslash.chevron.right", "checkmark.diamond.fill", "link", "info.circle.fill"
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            // SIDEBAR : Liste des apps
            sidebar
                .frame(width: 195)
                .background(bgSidebar)
            
            // CONTENU : Actions de l'application sélectionnée
            if let idx = store.profiles.firstIndex(where: { $0.bundleIdentifier == selectedProfileID }) {
                detailView(for: $store.profiles[idx])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(bgMain)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .preferredColorScheme(.dark)
        .onDisappear {
            stopRecordingShortcut()
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Espace pour les boutons macOS (fermer/réduire)
            Spacer().frame(height: 38)
            
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(store.profiles) { profile in
                        sidebarRow(profile)
                    }
                }
                .padding(.horizontal, 10)
            }
            
            // Bouton discret d'ajout en bas
            HStack {
                Button {
                    pickApplication()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Ajouter une app")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(10)
        }
    }
    
    @ViewBuilder
    private func sidebarRow(_ profile: AppProfile) -> some View {
        let isSelected = (selectedProfileID == profile.bundleIdentifier)
        
        Button {
            selectedProfileID = profile.bundleIdentifier
        } label: {
            HStack(spacing: 10) {
                appIcon(for: profile, size: 18)
                
                Text(profile.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.65))
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.white.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Vue Principale
    
    @ViewBuilder
    private func detailView(for profile: Binding<AppProfile>) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // En-tête : Titre de l'app à gauche, Pastilles de thème à droite
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    appIcon(for: profile.wrappedValue, size: 24)
                    Text(profile.wrappedValue.displayName)
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Spacer()
                
                // Sélecteur de thème minimaliste (pastilles de couleur)
                HStack(spacing: 8) {
                    ForEach(RingTheme.allCases) { theme in
                        let isSelected = (store.selectedTheme == theme)
                        Button {
                            store.selectedTheme = theme
                        } label: {
                            Circle()
                                .fill(Color(hex: theme.overrideAccentHex ?? 0xFFFFFF))
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: isSelected ? 2 : 0)
                                        .padding(-2)
                                )
                                .opacity(isSelected ? 1.0 : 0.45)
                        }
                        .buttonStyle(.plain)
                        .help(theme.displayName)
                    }
                }
                
                if profile.wrappedValue.bundleIdentifier != AppProfile.globalBundleID {
                    Button {
                        let id = selectedProfileID
                        selectedProfileID = AppProfile.globalBundleID
                        store.removeProfile(bundleIdentifier: id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                }
            }
            .padding(.top, 28)
            .padding(.horizontal, 28)
            
            // Liste des actions
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(profile.wrappedValue.slices.enumerated()), id: \.element.id) { index, _ in
                        sliceRow(
                            slice: Binding(
                                get: { profile.wrappedValue.slices[index] },
                                set: { newValue in
                                    profile.wrappedValue.slices[index] = newValue
                                    store.save()
                                }
                            ),
                            onDelete: {
                                let idToRemove = profile.wrappedValue.slices[index].id
                                profile.wrappedValue.slices.removeAll { $0.id == idToRemove }
                                store.save()
                            }
                        )
                    }
                    
                    // Bouton + Nouvelle action
                    Button {
                        let newSlice = RadialSlice(
                            title: "Action",
                            systemImage: "bolt.fill",
                            accentColorHex: 0xDC2626,
                            payload: .shortcut(keyCode: 0, flags: .maskCommand)
                        )
                        profile.wrappedValue.slices.append(newSlice)
                        store.save()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Ajouter une action")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
            }
            
            // Pied de page minimaliste
            HStack(spacing: 20) {
                Toggle("Exécution directe au survol", isOn: $store.instantHoverTrigger)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                Toggle("Clic droit rapide = menu macOS", isOn: $store.allowQuickRightClickPassThrough)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 18)
        }
    }
    
    @ViewBuilder
    private func sliceRow(slice: Binding<RadialSlice>, onDelete: @escaping () -> Void) -> some View {
        let isRecording = (recordingSliceID == slice.wrappedValue.id)
        
        HStack(spacing: 10) {
            // Icône
            Menu {
                ForEach(symbols, id: \.self) { sym in
                    Button {
                        slice.wrappedValue.systemImage = sym
                    } label: {
                        Label(sym, systemImage: sym)
                    }
                }
            } label: {
                Image(systemName: slice.wrappedValue.systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(bgField)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            
            // Nom de l'action
            TextField("Nom", text: slice.title)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(bgField)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Type (Raccourci / Shell)
            Picker("", selection: slice.payload.type) {
                ForEach(ActionPayloadType.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .labelsHidden()
            .frame(width: 100)
            
            // Raccourci ou Commande
            if slice.wrappedValue.payload.type == .keyShortcut {
                Button {
                    if isRecording {
                        stopRecordingShortcut()
                    } else {
                        startRecordingShortcut(for: slice)
                    }
                } label: {
                    Text(isRecording ? "Appuyez..." : slice.wrappedValue.payload.humanReadableShortcut)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(isRecording ? accent : .white)
                        .frame(width: 120, height: 30)
                        .background(isRecording ? accent.opacity(0.18) : bgField)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            } else {
                TextField("Commande...", text: slice.payload.scriptOrCommand)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 10)
                    .frame(width: 120, height: 30)
                    .background(bgField)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Supprimer
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func appIcon(for profile: AppProfile, size: CGFloat) -> some View {
        if profile.bundleIdentifier == AppProfile.globalBundleID {
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.75, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: size, height: size)
        } else if let path = profile.appPath, FileManager.default.fileExists(atPath: path) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: size, height: size)
        } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: profile.bundleIdentifier) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "app")
                .font(.system(size: size * 0.75))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }
    
    private func pickApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            if let created = store.addOrSelectApplication(url: url) {
                selectedProfileID = created.bundleIdentifier
            }
        }
    }
    
    private func startRecordingShortcut(for slice: Binding<RadialSlice>) {
        stopRecordingShortcut()
        recordingSliceID = slice.wrappedValue.id
        
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopRecordingShortcut()
                return nil
            }
            
            var cgFlags = CGEventFlags()
            if event.modifierFlags.contains(.command) { cgFlags.insert(.maskCommand) }
            if event.modifierFlags.contains(.shift) { cgFlags.insert(.maskShift) }
            if event.modifierFlags.contains(.option) { cgFlags.insert(.maskAlternate) }
            if event.modifierFlags.contains(.control) { cgFlags.insert(.maskControl) }
            
            slice.wrappedValue.payload = ActionPayload(
                type: .keyShortcut,
                keyCode: event.keyCode,
                modifiersRaw: cgFlags.rawValue,
                scriptOrCommand: ""
            )
            store.save()
            stopRecordingShortcut()
            return nil
        }
    }
    
    private func stopRecordingShortcut() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        recordingSliceID = nil
    }
}