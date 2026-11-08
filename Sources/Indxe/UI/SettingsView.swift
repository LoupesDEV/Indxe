import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var store: ProfileStore
    @State private var selectedProfileID: String = AppProfile.globalBundleID
    @State private var recordingSliceID: UUID? = nil
    @State private var keyMonitor: Any? = nil
    @State private var previewHoveredSliceIndex: Int? = 0
    
    // Palette Swiss Industrial
    private let surfacePrimary = Color(hex: 0x0A0A0C)
    private let surfaceSecondary = Color(hex: 0x0E0E11)
    private let surfaceElevated = Color(hex: 0x141418)
    private let hairline = Color(hex: 0x1F1F24)
    private let textPrimary = Color(hex: 0xF4F4F5)
    private let textMuted = Color(hex: 0x71717A)
    private let accentCrimson = Color(hex: 0xDC2626)
    
    private let symbolCatalog: [String] = [
        "command", "hammer.fill", "play.fill", "playpause.fill", "forward.end.fill", "backward.end.fill",
        "trash.fill", "magnifyingglass", "sparkle.magnifyingglass", "terminal.fill", "apple.terminal",
        "doc.on.doc.fill", "doc.on.clipboard.fill", "camera.viewfinder", "macwindow.on.rectangle",
        "arrow.uturn.backward.circle.fill", "plus.square.on.square", "xmark.square", "arrow.clockwise",
        "rectangle.split.2x1", "rectangle.split.1x2", "sidebar.left", "gearshape.fill", "folder.badge.plus",
        "bolt.fill", "eye.slash.fill", "mic.slash.fill", "speaker.slash.fill", "speaker.wave.3.fill",
        "chevron.left.forwardslash.chevron.right", "checkmark.diamond.fill", "link", "info.circle.fill"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // BARRE D'ESPACE SUPÉRIEURE (Pour laisser respirer les feux tricolores macOS)
            topArchitecturalBar
            
            Rectangle().fill(hairline).frame(height: 1)
            
            HStack(spacing: 0) {
                // COLONNE 01 : REGISTRE DES CONTEXTES (SIDEBAR)
                contextRegistrySidebar
                    .frame(width: 230)
                    .background(surfacePrimary)
                
                Rectangle().fill(hairline).frame(width: 1)
                
                if let profileIndex = store.profiles.firstIndex(where: { $0.bundleIdentifier == selectedProfileID }) {
                    // COLONNE 02 : MATRICE DES SECTEURS (CENTRE)
                    sectorMatrixView(for: $store.profiles[profileIndex])
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(surfacePrimary)
                    
                    Rectangle().fill(hairline).frame(width: 1)
                    
                    // COLONNE 03 : BANC DE CALIBRATION & THÈMES (DROITE)
                    calibrationInspector(profile: store.profiles[profileIndex])
                        .frame(width: 330)
                        .background(surfaceSecondary)
                } else {
                    Spacer()
                }
            }
        }
        .frame(minWidth: 1120, minHeight: 680)
        .background(surfacePrimary)
        .preferredColorScheme(.dark)
        .onDisappear {
            stopRecordingShortcut()
        }
    }
    
    // MARK: - Top Architectural Header
    
    private var topArchitecturalBar: some View {
        HStack(spacing: 0) {
            // Espace réservé aux boutons de fenêtre macOS (Close/Min/Max)
            Spacer().frame(width: 78)
            
            HStack(spacing: 8) {
                Rectangle()
                    .fill(accentCrimson)
                    .frame(width: 8, height: 8)
                
                Text("INDXE")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(2.0)
                    .foregroundStyle(textPrimary)
                
                Text("// RADIAL INPUT MATRIX")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(textMuted)
            }
            
            Spacer()
            
            HStack(spacing: 18) {
                HStack(spacing: 6) {
                    Text("THEME:")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(textMuted)
                    Text(store.selectedTheme.displayName)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(textPrimary)
                }
                
                Rectangle().fill(hairline).frame(width: 1, height: 14)
                
                HStack(spacing: 6) {
                    Text("MODE:")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(textMuted)
                    Text(store.instantHoverTrigger ? "INSTANT_VECTOR" : "HOLD_RELEASE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(accentCrimson)
                }
            }
            .padding(.trailing, 18)
        }
        .frame(height: 38)
        .background(surfaceSecondary)
    }
    
    // MARK: - Colonne 01 : Registre des Applications
    
    private var contextRegistrySidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // En-tête de section
            HStack {
                Text("01 // TARGETS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(textMuted)
                Spacer()
                Text("[\(store.profiles.count)]")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(textMuted)
            }
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(surfaceSecondary)
            
            Rectangle().fill(hairline).frame(height: 1)
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(store.profiles) { profile in
                        contextRow(profile)
                        Rectangle().fill(hairline.opacity(0.6)).frame(height: 1)
                    }
                }
            }
            
            Rectangle().fill(hairline).frame(height: 1)
            
            // Barre d'outils inférieure
            HStack(spacing: 0) {
                Button {
                    pickApplication()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("ADD TARGET")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                    }
                    .foregroundStyle(textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Rectangle().fill(hairline).frame(width: 1)
                
                Button {
                    store.restoreFactoryDefaults()
                    selectedProfileID = AppProfile.globalBundleID
                } label: {
                    Text("RESET")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(textMuted)
                        .frame(width: 64, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Restaurer les profils d'usine")
            }
            .frame(height: 36)
            .background(surfaceSecondary)
        }
    }
    
    @ViewBuilder
    private func contextRow(_ profile: AppProfile) -> some View {
        let isSelected = (selectedProfileID == profile.bundleIdentifier)
        let isGlobal = (profile.bundleIdentifier == AppProfile.globalBundleID)
        
        Button {
            selectedProfileID = profile.bundleIdentifier
            previewHoveredSliceIndex = 0
        } label: {
            HStack(spacing: 10) {
                // Indicateur franc de sélection (Barre verticale 2px)
                Rectangle()
                    .fill(isSelected ? accentCrimson : Color.clear)
                    .frame(width: 2)
                
                appIconView(for: profile, size: 18)
                    .padding(.leading, 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isGlobal ? "GLOBAL FALLBACK" : profile.displayName.uppercased())
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .monospaced))
                        .foregroundStyle(isSelected ? textPrimary : textPrimary.opacity(0.75))
                        .lineLimit(1)
                    
                    Text(isGlobal ? "*.*" : profile.bundleIdentifier)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(textMuted)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(String(format: "%02d", profile.slices.count))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(isSelected ? accentCrimson : textMuted)
                    .padding(.trailing, 14)
            }
            .frame(height: 44)
            .background(isSelected ? surfaceElevated : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Colonne 02 : Matrice des Secteurs (Table Tabulaire)
    
    @ViewBuilder
    private func sectorMatrixView(for profile: Binding<AppProfile>) -> some View {
        let sliceCount = profile.wrappedValue.slices.count
        
        VStack(alignment: .leading, spacing: 0) {
            // En-tête du profil actif
            HStack(alignment: .center, spacing: 14) {
                appIconView(for: profile.wrappedValue, size: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(profile.wrappedValue.displayName.uppercased())
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(textPrimary)
                        
                        Text("// \(profile.wrappedValue.bundleIdentifier)")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(textMuted)
                    }
                    
                    Text("SECTOR RESOLUTION: \(sliceCount > 0 ? Int(360.0 / Double(sliceCount)) : 0)° PER SLICE")
                        .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(textMuted)
                }
                
                Spacer()
                
                if profile.wrappedValue.bundleIdentifier != AppProfile.globalBundleID {
                    Button {
                        let id = selectedProfileID
                        selectedProfileID = AppProfile.globalBundleID
                        store.removeProfile(bundleIdentifier: id)
                    } label: {
                        Text("DELETE PROFILE")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(textMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(Rectangle().strokeBorder(hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                
                Button {
                    let newSlice = RadialSlice(
                        title: "CMD_\(sliceCount + 1)",
                        systemImage: "bolt.fill",
                        accentColorHex: 0xDC2626,
                        payload: .shortcut(keyCode: 0, flags: .maskCommand)
                    )
                    profile.wrappedValue.slices.append(newSlice)
                    store.save()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("APPEND SECTOR")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accentCrimson)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .frame(height: 62)
            .background(surfacePrimary)
            
            Rectangle().fill(hairline).frame(height: 1)
            
            // En-tête de colonnes de la table (Style tableur technique)
            HStack(spacing: 0) {
                Text("IDX / ARC")
                    .frame(width: 86, alignment: .leading)
                Text("SYM")
                    .frame(width: 44, alignment: .center)
                Text("LABEL")
                    .frame(width: 145, alignment: .leading)
                Text("VECTOR TYPE")
                    .frame(width: 115, alignment: .leading)
                Text("PAYLOAD / KEYBIND")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("ORD")
                    .frame(width: 68, alignment: .trailing)
            }
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .foregroundStyle(textMuted)
            .padding(.horizontal, 20)
            .frame(height: 28)
            .background(surfaceSecondary)
            
            Rectangle().fill(hairline).frame(height: 1)
            
            // Lignes de la table
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(profile.wrappedValue.slices.enumerated()), id: \.element.id) { index, _ in
                        sectorTableRow(
                            slice: Binding(
                                get: { profile.wrappedValue.slices[index] },
                                set: { newValue in
                                    profile.wrappedValue.slices[index] = newValue
                                    store.save()
                                }
                            ),
                            index: index,
                            totalCount: sliceCount,
                            onMoveUp: {
                                guard index > 0 else { return }
                                profile.wrappedValue.slices.swapAt(index, index - 1)
                                store.save()
                            },
                            onMoveDown: {
                                guard index < sliceCount - 1 else { return }
                                profile.wrappedValue.slices.swapAt(index, index + 1)
                                store.save()
                            },
                            onDelete: {
                                let idToRemove = profile.wrappedValue.slices[index].id
                                profile.wrappedValue.slices.removeAll { $0.id == idToRemove }
                                store.save()
                            }
                        )
                        Rectangle().fill(hairline).frame(height: 1)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func sectorTableRow(
        slice: Binding<RadialSlice>,
        index: Int,
        totalCount: Int,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        let isRecording = (recordingSliceID == slice.wrappedValue.id)
        let isHoveredInPreview = (previewHoveredSliceIndex == index)
        let stepDeg = 360.0 / Double(max(totalCount, 1))
        let centerDeg = Int(round(Double(index) * stepDeg)) % 360
        
        HStack(spacing: 0) {
            // 1. Index + Angle Polaire
            HStack(spacing: 6) {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(isHoveredInPreview ? accentCrimson : textPrimary)
                
                Text(String(format: "%03d°", centerDeg))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(textMuted)
            }
            .frame(width: 86, alignment: .leading)
            
            // 2. Sélecteur d'icône SF Symbol
            Menu {
                ForEach(symbolCatalog, id: \.self) { sym in
                    Button {
                        slice.wrappedValue.systemImage = sym
                    } label: {
                        Label(sym, systemImage: sym)
                    }
                }
            } label: {
                ZStack {
                    Rectangle()
                        .fill(surfaceSecondary)
                        .frame(width: 28, height: 28)
                        .overlay(Rectangle().strokeBorder(hairline, lineWidth: 1))
                    Image(systemName: slice.wrappedValue.systemImage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(textPrimary)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 44, alignment: .center)
            
            // 3. Champ Label éditable sur grille
            TextField("LABEL", text: slice.title)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(textPrimary)
                .padding(.horizontal, 8)
                .frame(width: 135, height: 28)
                .background(surfaceSecondary)
                .overlay(Rectangle().strokeBorder(hairline, lineWidth: 1))
                .padding(.trailing, 10)
            
            // 4. Sélecteur de Type d'Action (Cycle au clic pour éviter les menus déroulants lourds)
            Menu {
                ForEach(ActionPayloadType.allCases) { kind in
                    Button(kind.rawValue) {
                        slice.wrappedValue.payload.type = kind
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(slice.wrappedValue.payload.type.rawValue)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(textMuted)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(textMuted)
                }
                .padding(.horizontal, 8)
                .frame(width: 105, height: 28)
                .background(surfaceSecondary)
                .overlay(Rectangle().strokeBorder(hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
            
            // 5. Keycap Recorder ou Script Field
            if slice.wrappedValue.payload.type == .keyShortcut {
                Button {
                    if isRecording {
                        stopRecordingShortcut()
                    } else {
                        startRecordingShortcut(for: slice)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(isRecording ? accentCrimson : textMuted.opacity(0.4))
                            .frame(width: 5, height: 5)
                        
                        Text(isRecording ? "PRESS KEYS [ESC TO CANCEL]" : slice.wrappedValue.payload.humanReadableShortcut)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(isRecording ? accentCrimson : textPrimary)
                        
                        Spacer()
                        
                        Text("REC")
                            .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                            .foregroundStyle(textMuted)
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)
                    .background(isRecording ? accentCrimson.opacity(0.12) : surfaceSecondary)
                    .overlay(
                        Rectangle()
                            .strokeBorder(isRecording ? accentCrimson : hairline, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                TextField(
                    slice.wrappedValue.payload.type == .shellCommand ? "/bin/zsh -c ..." : "tell application ...",
                    text: slice.payload.scriptOrCommand
                )
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(textPrimary)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)
                .background(surfaceSecondary)
                .overlay(Rectangle().strokeBorder(hairline, lineWidth: 1))
            }
            
            // 6. Contrôles d'ordre & suppression
            HStack(spacing: 8) {
                Button(action: onMoveUp) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10))
                        .foregroundStyle(index == 0 ? textMuted.opacity(0.2) : textMuted)
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                
                Button(action: onMoveDown) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10))
                        .foregroundStyle(index == totalCount - 1 ? textMuted.opacity(0.2) : textMuted)
                }
                .buttonStyle(.plain)
                .disabled(index == totalCount - 1)
                
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(textMuted)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 68, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .frame(height: 46)
        .background(isHoveredInPreview ? surfaceElevated.opacity(0.55) : Color.clear)
        .onHover { hovering in
            if hovering {
                previewHoveredSliceIndex = index
            }
        }
    }
    
    // MARK: - Colonne 03 : Banc de Calibration CAD & Thèmes
    
    @ViewBuilder
    private func calibrationInspector(profile: AppProfile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section 02 : Aperçu Géométrique
            HStack {
                Text("02 // GEOMETRY MONITOR")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(textMuted)
                Spacer()
                if let idx = previewHoveredSliceIndex {
                    Text(String(format: "ACTIVE: S%02d", idx + 1))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(accentCrimson)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 34)
            
            Rectangle().fill(hairline).frame(height: 1)
            
            // Viewport avec grille CAD
            ZStack {
                surfacePrimary
                
                // Axes réticulaires de visée (Blueprint Grid)
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    Path { path in
                        path.move(to: CGPoint(x: w / 2, y: 0))
                        path.addLine(to: CGPoint(x: w / 2, y: h))
                        path.move(to: CGPoint(x: 0, y: h / 2))
                        path.addLine(to: CGPoint(x: w, y: h / 2))
                    }
                    .stroke(hairline.opacity(0.9), lineWidth: 0.75)
                }
                
                RadialRingCanvas(
                    profile: profile,
                    theme: store.selectedTheme,
                    selectedIndex: previewHoveredSliceIndex,
                    currentAngleDegrees: nil,
                    deadZoneRadius: 28.0,
                    outerRadius: 112.0
                )
                .scaleEffect(0.88)
                
                // Télémétrie en bas du viewport
                VStack {
                    Spacer()
                    HStack {
                        Text("R_IN: 28.0pt")
                        Spacer()
                        Text("R_TRIG: 78.0pt")
                        Spacer()
                        Text("R_OUT: 135.0pt")
                    }
                    .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(textMuted)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            .frame(height: 275)
            
            Rectangle().fill(hairline).frame(height: 1)
            
            // Section 03 : Sélecteur de Palette / Thème
            HStack {
                Text("03 // COLORIMETRY & THEME")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(textMuted)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 32)
            
            Rectangle().fill(hairline).frame(height: 1)
            
            VStack(spacing: 0) {
                ForEach(RingTheme.allCases) { theme in
                    themeSelectorRow(theme)
                    Rectangle().fill(hairline).frame(height: 1)
                }
            }
            
            // Section 04 : Paramètres Matériels CGEventTap
            HStack {
                Text("04 // HID ENGINE PARAMETERS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(textMuted)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 32)
            
            Rectangle().fill(hairline).frame(height: 1)
            
            VStack(spacing: 0) {
                mechanicalToggleRow(
                    title: "INSTANT VECTOR TRIGGER",
                    subtitle: "Exécute à R >= 78pt sans attendre MouseUp",
                    isOn: $store.instantHoverTrigger
                )
                
                Rectangle().fill(hairline).frame(height: 1)
                
                mechanicalToggleRow(
                    title: "NATIVE PASS-THROUGH (<180ms)",
                    subtitle: "Clic droit sec au centre ouvre le menu macOS",
                    isOn: $store.allowQuickRightClickPassThrough
                )
                
                Rectangle().fill(hairline).frame(height: 1)
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func themeSelectorRow(_ theme: RingTheme) -> some View {
        let isSelected = (store.selectedTheme == theme)
        
        Button {
            store.selectedTheme = theme
        } label: {
            HStack(spacing: 10) {
                Text(theme.codeName)
                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(isSelected ? accentCrimson : textMuted)
                
                // Pastilles chromatiques rectangulaires strictes
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(hex: theme.sliceBackgroundHex))
                        .frame(width: 12, height: 12)
                    Rectangle()
                        .fill(Color(hex: theme.overrideAccentHex ?? 0xF4F4F5))
                        .frame(width: 12, height: 12)
                }
                .overlay(Rectangle().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
                
                Text(theme.displayName)
                    .font(.system(size: 10.5, weight: isSelected ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(isSelected ? textPrimary : textMuted)
                
                Spacer()
                
                Text(isSelected ? "[ACTIVE]" : "")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentCrimson)
            }
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background(isSelected ? surfaceElevated : surfacePrimary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func mechanicalToggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(textPrimary)
                    Text(subtitle)
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(textMuted)
                }
                
                Spacer()
                
                // Interrupteur rectangulaire mécanique (Non-Apple Switch)
                HStack(spacing: 0) {
                    Text(isOn.wrappedValue ? "ON" : "OFF")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(isOn.wrappedValue ? .white : textMuted)
                        .frame(width: 36, height: 20)
                        .background(isOn.wrappedValue ? accentCrimson : surfacePrimary)
                        .overlay(
                            Rectangle()
                                .strokeBorder(isOn.wrappedValue ? accentCrimson : hairline, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(surfacePrimary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Utilitaires Système
    
    @ViewBuilder
    private func appIconView(for profile: AppProfile, size: CGFloat) -> some View {
        if profile.bundleIdentifier == AppProfile.globalBundleID {
            ZStack {
                Rectangle()
                    .fill(accentCrimson.opacity(0.15))
                    .frame(width: size, height: size)
                    .overlay(Rectangle().strokeBorder(accentCrimson, lineWidth: 1))
                Text("G")
                    .font(.system(size: size * 0.55, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentCrimson)
            }
        } else if let path = profile.appPath, FileManager.default.fileExists(atPath: path) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: size, height: size)
        } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: profile.bundleIdentifier) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                .resizable()
                .frame(width: size, height: size)
        } else {
            Rectangle()
                .strokeBorder(hairline, lineWidth: 1)
                .frame(width: size, height: size)
        }
    }
    
    private func pickApplication() {
        let panel = NSOpenPanel()
        panel.title = "Sélectionner une application cible"
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