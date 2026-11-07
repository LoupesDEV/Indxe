import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var store: ProfileStore
    @State private var selectedProfileID: String = AppProfile.globalBundleID
    @State private var recordingSliceID: UUID? = nil
    @State private var keyMonitor: Any? = nil
    
    private let suggestedSymbols: [String] = [
        "command", "hammer.fill", "play.fill", "trash.fill", "magnifyingglass",
        "terminal.fill", "apple.terminal", "doc.on.doc.fill", "doc.on.clipboard.fill",
        "camera.viewfinder", "macwindow.on.rectangle", "arrow.uturn.backward.circle.fill",
        "sparkle.magnifyingglass", "plus.square.on.square", "xmark.square",
        "arrow.clockwise", "rectangle.split.2x1", "gearshape.fill", "folder.fill",
        "bolt.fill", "wand.and.stars", "paintbrush.fill", "speaker.wave.3.fill", "lock.fill"
    ]
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedProfileID) {
                    Section("Profil par Défaut") {
                        ForEach(store.profiles.filter { $0.bundleIdentifier == AppProfile.globalBundleID }) { profile in
                            profileRow(profile)
                                .tag(profile.bundleIdentifier)
                        }
                    }
                    
                    Section("Applications Spécifiques") {
                        ForEach(store.profiles.filter { $0.bundleIdentifier != AppProfile.globalBundleID }) { profile in
                            profileRow(profile)
                                .tag(profile.bundleIdentifier)
                        }
                    }
                }
                .listStyle(.sidebar)
                
                Divider()
                
                HStack(spacing: 8) {
                    Button {
                        pickApplication()
                    } label: {
                        Label("Ajouter une App", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: 0xDC2626))
                    
                    if selectedProfileID != AppProfile.globalBundleID {
                        Button(role: .destructive) {
                            let toDelete = selectedProfileID
                            selectedProfileID = AppProfile.globalBundleID
                            store.removeProfile(bundleIdentifier: toDelete)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                .padding(10)
            }
            .navigationSplitViewColumnWidth(min: 230, ideal: 250)
        } detail: {
            if let profileIndex = store.profiles.firstIndex(where: { $0.bundleIdentifier == selectedProfileID }) {
                profileEditor(for: $store.profiles[profileIndex])
            } else {
                Text("Sélectionnez un profil à gauche")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 880, minHeight: 580)
        .onDisappear {
            stopRecordingShortcut()
        }
    }
    
    @ViewBuilder
    private func profileRow(_ profile: AppProfile) -> some View {
        HStack(spacing: 10) {
            if profile.bundleIdentifier == AppProfile.globalBundleID {
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xDC2626))
                    .frame(width: 24, height: 24)
            } else if let path = profile.appPath, FileManager.default.fileExists(atPath: path) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 18))
                    .frame(width: 24, height: 24)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.displayName)
                    .font(.system(size: 13, weight: .medium))
                Text(profile.bundleIdentifier == AppProfile.globalBundleID ? "Fallback universel" : profile.bundleIdentifier)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
    
    @ViewBuilder
    private func profileEditor(for profile: Binding<AppProfile>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // En-tête du profil + Options de comportement du clic droit
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.wrappedValue.displayName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Bundle ID : \(profile.wrappedValue.bundleIdentifier)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Toggle("Exécuter dès le survol (sans attendre de relâcher)", isOn: $store.instantHoverTrigger)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    
                    Toggle("Clic droit rapide sur place = Menu macOS natif", isOn: $store.allowQuickRightClickPassThrough)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            .padding(18)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Liste des tranches (Slices) du menu radial
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(profile.slices) { $slice in
                        sliceEditorCard(slice: $slice, onDelete: {
                            profile.wrappedValue.slices.removeAll { $0.id == slice.id }
                            store.save()
                        })
                    }
                    
                    Button {
                        let newSlice = RadialSlice(
                            title: "Nouvelle Action",
                            systemImage: "bolt.fill",
                            accentColorHex: 0xDC2626,
                            payload: .shortcut(keyCode: 0, flags: .maskCommand)
                        )
                        profile.wrappedValue.slices.append(newSlice)
                        store.save()
                    } label: {
                        Label("Ajouter une tranche au Pie Menu", systemImage: "plus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(18)
            }
        }
        .onChange(of: profile.wrappedValue) { _, _ in
            store.save()
        }
    }
    
    @ViewBuilder
    private func sliceEditorCard(slice: Binding<RadialSlice>, onDelete: @escaping () -> Void) -> some View {
        let isRecording = (recordingSliceID == slice.wrappedValue.id)
        
        HStack(spacing: 14) {
            // Sélecteur de couleur d'accentuation
            ColorPicker("", selection: Binding(
                get: { Color(hex: slice.wrappedValue.accentColorHex) },
                set: { newColor in
                    slice.wrappedValue.accentColorHex = newColor.toHex()
                }
            ), supportsOpacity: false)
            .labelsHidden()
            .frame(width: 28)
            
            // Sélecteur d'icône SF Symbol
            Menu {
                ForEach(suggestedSymbols, id: \.self) { symbol in
                    Button {
                        slice.wrappedValue.systemImage = symbol
                    } label: {
                        Label(symbol, systemImage: symbol)
                    }
                }
            } label: {
                Image(systemName: slice.wrappedValue.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .frame(width: 52)
            
            // Nom de la tranche
            TextField("Titre", text: slice.title)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
            
            // Type d'action
            Picker("", selection: slice.payload.type) {
                ForEach(ActionPayloadType.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .labelsHidden()
            .frame(width: 150)
            
            // Configuration de la charge utile (Raccourci ou Commande)
            if slice.wrappedValue.payload.type == .keyShortcut {
                Button {
                    if isRecording {
                        stopRecordingShortcut()
                    } else {
                        startRecordingShortcut(for: slice)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isRecording ? "record.circle.fill" : "keyboard")
                            .foregroundStyle(isRecording ? Color.red : Color.secondary)
                        Text(isRecording ? "Appuyez sur les touches..." : slice.wrappedValue.payload.humanReadableShortcut)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .tint(isRecording ? .red : .primary)
            } else {
                TextField(
                    slice.wrappedValue.payload.type == .shellCommand ? "Ex: open -a Terminal" : "Code AppleScript...",
                    text: slice.payload.scriptOrCommand
                )
                .font(.system(size: 12, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
            }
            
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Sélecteur d'Application (.app)
    
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
    
    // MARK: - Enregistreur de Raccourci Clavier Temps Réel
    
    private func startRecordingShortcut(for slice: Binding<RadialSlice>) {
        stopRecordingShortcut()
        recordingSliceID = slice.wrappedValue.id
        
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Touche Échap annule l'enregistrement
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