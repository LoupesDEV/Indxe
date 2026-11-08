import SwiftUI
import AppKit

struct AnnularSectorShape: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

struct RadialMenuView: View {
    @Bindable var state: RingState
    var store: ProfileStore = .shared
    
    private let canvasSize: CGFloat = 340.0
    
    var body: some View {
        ZStack {
            if state.isVisible {
                RadialRingCanvas(
                    profile: state.activeProfile,
                    theme: store.selectedTheme,
                    selectedIndex: state.selectedIndex,
                    currentAngleDegrees: state.currentAngleDegrees,
                    deadZoneRadius: state.deadZoneRadius,
                    outerRadius: state.outerRadius
                )
            }
        }
        .frame(width: canvasSize, height: canvasSize)
    }
}

struct RadialRingCanvas: View {
    let profile: AppProfile
    let theme: RingTheme
    let selectedIndex: Int?
    let currentAngleDegrees: Double?
    let deadZoneRadius: CGFloat
    let outerRadius: CGFloat
    
    var body: some View {
        let slices = profile.slices
        let count = slices.count
        let sectorStep = 360.0 / Double(max(count, 1))
        let gap = theme.gapDegrees
        let baseText = Color(hex: theme.primaryTextHex)
        let selectedFg = Color(hex: theme.selectedForegroundHex)
        let hubAccent = Color(hex: theme.overrideAccentHex ?? 0xDC2626)
        
        ZStack {
            // Halo de contour extérieur subtil
            Circle()
                .strokeBorder(baseText.opacity(0.08), lineWidth: 1)
                .frame(width: outerRadius * 2 + 12, height: outerRadius * 2 + 12)
            
            ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                let isSelected = (selectedIndex == index)
                let centerDeg = Double(index) * sectorStep - 90.0
                let startDeg = centerDeg - (sectorStep / 2.0) + (gap / 2.0)
                let endDeg = centerDeg + (sectorStep / 2.0) - (gap / 2.0)
                
                let activeAccentHex = theme.overrideAccentHex ?? slice.accentColorHex
                let activeFill = Color(hex: activeAccentHex)
                let inactiveFill = Color(hex: theme.sliceBackgroundHex)
                let currentOuter = isSelected ? (outerRadius + theme.ringExpansionOnHover) : outerRadius
                
                ZStack {
                    AnnularSectorShape(
                        startAngle: .degrees(startDeg),
                        endAngle: .degrees(endDeg),
                        innerRadius: deadZoneRadius + 6,
                        outerRadius: currentOuter
                    )
                    .fill(isSelected ? activeFill.opacity(0.95) : inactiveFill.opacity(0.92))
                    .overlay(
                        AnnularSectorShape(
                            startAngle: .degrees(startDeg),
                            endAngle: .degrees(endDeg),
                            innerRadius: deadZoneRadius + 6,
                            outerRadius: currentOuter
                        )
                        .stroke(
                            isSelected ? baseText.opacity(0.9) : baseText.opacity(theme.borderOpacity),
                            lineWidth: isSelected ? 1.8 : 1.0
                        )
                    )
                    
                    // Petit indicateur coloré discret quand le thème est monochrome mais que la tranche a sa propre couleur
                    let midRadius = (deadZoneRadius + 6 + currentOuter) / 2.0
                    let rad = centerDeg * .pi / 180.0
                    let iconX = cos(rad) * midRadius
                    let iconY = sin(rad) * midRadius
                    
                    VStack(spacing: 4) {
                        Image(systemName: slice.systemImage)
                            .font(.system(size: isSelected ? 20 : 17, weight: .semibold))
                            .foregroundStyle(isSelected ? selectedFg : baseText.opacity(0.88))
                        
                        Text(slice.title)
                            .font(.system(
                                size: 10,
                                weight: isSelected ? .bold : .medium,
                                design: theme == .terminalMatrix || theme == .swissMinimal ? .monospaced : .rounded
                            ))
                            .foregroundStyle(isSelected ? selectedFg : baseText.opacity(0.68))
                            .lineLimit(1)
                    }
                    .offset(x: iconX, y: iconY)
                }
                .animation(.spring(response: 0.16, dampingFraction: 0.76), value: selectedIndex)
            }
            
            // Noyau HUD Central
            ZStack {
                Circle()
                    .fill(Color(hex: theme.centerHubHex).opacity(0.96))
                    .frame(width: deadZoneRadius * 2, height: deadZoneRadius * 2)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                selectedIndex != nil ? hubAccent.opacity(0.85) : baseText.opacity(0.22),
                                lineWidth: 1.5
                            )
                    )
                
                VStack(spacing: 1) {
                    if let idx = selectedIndex, idx < slices.count {
                        Text(slices[idx].payload.humanReadableShortcut)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(hubAccent)
                            .lineLimit(1)
                    } else {
                        Text(profile.displayName.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(baseText.opacity(0.75))
                            .lineLimit(1)
                    }
                }
                .frame(width: deadZoneRadius * 1.75)
            }
            
            // Curseur orbital sur le périmètre de la deadzone
            if let angleDeg = currentAngleDegrees {
                let indicatorRad = (angleDeg - 90.0) * .pi / 180.0
                let r = deadZoneRadius + 1
                Circle()
                    .fill(hubAccent)
                    .frame(width: 6, height: 6)
                    .offset(x: cos(indicatorRad) * r, y: sin(indicatorRad) * r)
            }
        }
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> UInt32 {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? .systemBlue
        let r = UInt32(max(0, min(255, Int(round(nsColor.redComponent * 255)))))
        let g = UInt32(max(0, min(255, Int(round(nsColor.greenComponent * 255)))))
        let b = UInt32(max(0, min(255, Int(round(nsColor.blueComponent * 255)))))
        return (r << 16) | (g << 8) | b
    }
}