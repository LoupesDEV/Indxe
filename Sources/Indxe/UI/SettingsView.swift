import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var store: ProfileStore
    @State private var selectedProfileID: String = AppProfile.globalBundleID
    @State private var recordingSliceID: UUID? = nil
    @State private var keyMonitor: Any? = nil
    @State private var previewHoveredSliceIndex: Int? = 0
    
    private let bgCanvas = Color(hex: 0x0D1117)
    private let bgCard = Color(hex: 0x161B22)
    private let bgSidebar = Color(hex: 0x090C10)
    private let crimson = Color(hex: 0xDC2626)
    
    private let suggestedSymbols: [String] = [
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
            // COLONNE 1 : SIDEBAR DES PROFILS D'APPLICATIONS
            sidebarColumn
                .frame(width: 245)
                .background(bgSidebar)
            
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 1)
            
            // COLONNE 2 : ÉDITEUR CENTRAL + SÉLECTEUR DE THÈMES
            if let profileIndex = store.profiles.firstIndex(where: { $0.bundleIdentifier == selectedProfileID }) {
                mainEditorColumn(for: $store.profiles[profileIndex])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(bgCanvas)
                
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 1)
                
                // COLONNE 3 : APERÇU INTERACTIF EN DIRECT + RÉGLAGES MOTEUR
                livePreviewColumn(profile: store.profiles[profileIndex])
                    .frame(width: 320)
                    .background(bgSidebar)
            } else {
                VStack {
                    Text("Sélectionnez un profil")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(bgCanvas)
            }
        }
        .frame(minWidth: 1120, minHeight: 680)
        .preferredColorScheme(.dark)
        .onDisappear {
            stopRecordingShortcut()
        }
    }
    
    // MARK: - Colonne 1 : Sidebar
    
    private var sidebarColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(crimson.opacity(0.18))
                        .frame(width: 28, height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(crimson.opacity(0.6), lineWidth: 1)
                        )
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(crimson)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("INDXE")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .tracking(1.5)
                    Text("RADIAL ENGINE v2")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            
            Divider().opacity(0.3)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Section Global
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SYSTÈME")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                        
                        ForEach(store.profiles.filter { $0.bundleIdentifier == AppProfile.globalBundleID }) { profile in
                            sidebarItem(profile)
                        }
                    }
                    
                    // Section Applications
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("APPLICATIONS (\(store.profiles.count - 1))")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        
                        ForEach(store.profiles.filter { $0.bundleIdentifier != AppProfile.globalBundleID }) { profile in
                            sidebarItem(profile)
                        }
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 8)
            }
            
            Divider().opacity(0.3)
            
            // Actions bas de sidebar
            VStack(spacing: 8) {
                Button {
                    pickApplication()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.app.fill")
                        Text("Ajouter une Application")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(crimson)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                
                HStack(spacing: 8) {
                    Button {
                        store.restoreFactoryDefaults()
                        selectedProfileID = AppProfile.globalBundleID
                    } label: {
                        Label("Profils d'usine", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("Recharge tous les setups d'applications par défaut")
                    
                    if selectedProfileID != AppProfile.globalBundleID {
                        Button {
                            let id = selectedProfileID
                            selectedProfileID = AppProfile.globalBundleID
                            store.removeProfile(bundleIdentifier: id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.red)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(bgCard)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help("Supprimer ce profil d'application")
                    }
                }
            }
            .padding(12)
        }
    }
    
    @ViewBuilder
    private func sidebarItem(_ profile: AppProfile) -> some View {
        let isSelected = (selectedProfileID == profile.bundleIdentifier)
        
        Button {
            selectedProfileID = profile.bundleIdentifier
            previewHoveredSliceIndex = 0
        } label: {
            HStack(spacing: 10) {
                appIconView(for: profile, size: 22)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.displayName)
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.82))
                        .lineLimit(1)
                    
                    Text("\(profile.slices.count) actions")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(crimson)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.08) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? Color.white.opacity(0.14) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Colonne 2 : Éditeur Principal & Sélecteur de Thèmes
    
    @ViewBuilder
    private func mainEditorColumn(for profile: Binding<AppProfile>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sélecteur de Thème Visuel Horizontal
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("THÈME VISUEL DU PIE MENU")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                
                HStack(spacing: 10) {
                    ForEach(RingTheme.allCases) { theme in
                        themeCard(theme)
                    }
                }
            }
            .padding(18)
            .background(bgSidebar.opacity(0.5))
            
            Divider().opacity(0.3)
            
            // En-tête de l'application sélectionnée
            HStack(spacing: 12) {
                appIconView(for: profile.wrappedValue, size: 34)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.wrappedValue.displayName)
                        .font(.system(size: 18, weight: .bold))
                    Text(profile.wrappedValue.bundleIdentifier)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    let newSlice = RadialSlice(
                        title: "Action \(profile.wrappedValue.slices.count + 1)",
                        systemImage: "bolt.fill",
                        accentColorHex: 0xDC2626,
                        payload: .shortcut(keyCode: 0, flags: .maskCommand)
                    )
                    profile.wrappedValue.slices.append(newSlice)
                    store.save()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Nouvelle Tranche")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            Divider().opacity(0.2)
            
            // Liste des tranches (Slices)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(profile.wrappedValue.slices.enumerated()), id: \.element.id) { index, _ in
                        sliceEditorRow(
                            slice: Binding(
                                get: { profile.wrappedValue.slices[index] },
                                set: { newValue in
                                    profile.wrappedValue.slices[index] = newValue
                                    store.save()
                                }
                            ),
                            index: index,
                            totalCount: profile.wrappedValue.slices.count,
                            onMoveUp: {
                                guard index > 0 else { return }
                                profile.wrappedValue.slices.swapAt(index, index - 1)
                                store.save()
                            },
                            onMoveDown: {
                                guard index < profile.wrappedValue.slices.count - 1 else { return }
                                profile.wrappedValue.slices.swapAt(index, index + 1)
                                store.save()
                            },
                            onDelete: {
                                let idToRemove = profile.wrappedValue.slices[index].id
                                profile.wrappedValue.slices.removeAll { $0.id == idToRemove }
                                store.save()
                            }
                        )
                        .onHover { hovering in
                            if hovering {
                                previewHoveredSliceIndex = index
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
    }
    
    @ViewBuilder
    private func themeCard(_ theme: RingTheme) -> some View {
        let isSelected = (store.selectedTheme == theme)
        let previewAccent = Color(hex: theme.overrideAccentHex ?? 0x3B82F6)
        
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                store.selectedTheme = theme
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: theme.sliceBackgroundHex))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                    
                    Circle()
                        .fill(previewAccent)
                        .frame(width: 14, height: 14)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(crimson)
                    }
                }
                
                Text(theme.displayName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(theme.subtitle)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(bgCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? crimson : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func sliceEditorRow(
        slice: Binding<RadialSlice>,
        index: Int,
        totalCount: Int,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        let isRecording = (recordingSliceID == slice.wrappedValue.id)
        
        HStack(spacing: 10) {
            // Badge d'index + Flèches d'ordre
            VStack(spacing: 2) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .opacity(index == 0 ? 0.2 : 0.7)
                
                Text("#\(index + 1)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .disabled(index == totalCount - 1)
                .opacity(index == totalCount - 1 ? 0.2 : 0.7)
            }
            .frame(width: 24)
            
            // Couleur de la tranche (utile en mode Chroma Slate)
            ColorPicker("", selection: Binding(
                get: { Color(hex: slice.wrappedValue.accentColorHex) },
                set: { newColor in
                    slice.wrappedValue.accentColorHex = newColor.toHex()
                }
            ), supportsOpacity: false)
            .labelsHidden()
            .frame(width: 24)
            
            // Sélecteur SF Symbol
            Menu {
                ForEach(suggestedSymbols, id: \.self) { symbol in
                    Button {
                        slice.wrappedValue.systemImage = symbol
                    } label: {
                        Label(symbol, systemImage: symbol)
                    }
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 32, height: 32)
                    Image(systemName: slice.wrappedValue.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            .frame(width: 34)
            
            // Titre
            TextField("Nom", text: slice.title)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: 130)
            
            // Type d'action
            Picker("", selection: slice.payload.type) {
                ForEach(ActionPayloadType.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .labelsHidden()
            .frame(width: 135)
            
            // Raccourci ou Script
            if slice.wrappedValue.payload.type == .keyShortcut {
                Button {
                    if isRecording {
                        stopRecordingShortcut()
                    } else {
                        startRecordingShortcut(for: slice)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isRecording ? crimson : Color.white.opacity(0.3))
                            .frame(width: 6, height: 6)
                        Text(isRecording ? "Tapez le raccourci..." : slice.wrappedValue.payload.humanReadableShortcut)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isRecording ? crimson.opacity(0.22) : Color.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isRecording ? crimson : Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            } else {
                TextField(
                    slice.wrappedValue.payload.type == .shellCommand ? "Commande zsh..." : "Code AppleScript...",
                    text: slice.payload.scriptOrCommand
                )
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: .infinity)
            }
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(bgCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Colonne 3 : Aperçu Live & Comportement
    
    @ViewBuilder
    private func livePreviewColumn(profile: AppProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("APERÇU EN DIRECT")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.top, 18)
                .padding(.horizontal, 18)
            
            // Zone d'aperçu du Pie Menu à l'échelle
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                    )
                
                RadialRingCanvas(
                    profile: profile,
                    theme: store.selectedTheme,
                    selectedIndex: previewHoveredSliceIndex,
                    currentAngleDegrees: nil,
                    deadZoneRadius: 28.0,
                    outerRadius: 115.0
                )
                .scaleEffect(0.88)
            }
            .frame(height: 290)
            .padding(.horizontal, 16)
            
            // Sélecteur rapide de tranche simulée dans l'aperçu
            if !profile.slices.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(profile.slices.enumerated()), id: \.element.id) { idx, slice in
                            Button {
                                previewHoveredSliceIndex = idx
                            } label: {
                                Text(slice.title)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(previewHoveredSliceIndex == idx ? crimson : bgCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            Divider().opacity(0.3)
            
            // Réglages Moteur d'Interception
            VStack(alignment: .leading, spacing: 12) {
                Text("COMPORTEMENT DU CLIC DROIT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                Toggle(isOn: $store.instantHoverTrigger) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Exécution instantanée au glissement")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Valide l'option dès que le curseur entre dans la tranche sans attendre le relâchement.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                
                Toggle(isOn: $store.allowQuickRightClickPassThrough) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pass-through clic droit rapide")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Un clic droit sec (< 180 ms) sur place ouvre le menu contextuel macOS classique.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            .padding(.horizontal, 18)
            
            Spacer()
        }
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func appIconView(for profile: AppProfile, size: CGFloat) -> some View {
        if profile.bundleIdentifier == AppProfile.globalBundleID {
            Image(systemName: "globe")
                .font(.system(size: size * 0.72, weight: .semibold))
                .foregroundStyle(crimson)
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
            Image(systemName: "app.dashed")
                .font(.system(size: size * 0.72))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }
    
    private func pickApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choisir une application à configurer dans Indxe"
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