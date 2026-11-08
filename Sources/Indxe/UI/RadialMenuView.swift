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
            // Cercle de calibration extérieur
            Circle()
                .strokeBorder(baseText.opacity(0.12), style: StrokeStyle(lineWidth: 0.75, dash: [2, 4]))
                .frame(width: outerRadius * 2 + 14, height: outerRadius * 2 + 14)
            
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
                        innerRadius: deadZoneRadius + 4,
                        outerRadius: currentOuter
                    )
                    .fill(isSelected ? activeFill : inactiveFill.opacity(0.95))
                    .overlay(
                        AnnularSectorShape(
                            startAngle: .degrees(startDeg),
                            endAngle: .degrees(endDeg),
                            innerRadius: deadZoneRadius + 4,
                            outerRadius: currentOuter
                        )
                        .stroke(
                            isSelected ? activeFill : baseText.opacity(theme.borderOpacity),
                            lineWidth: isSelected ? 1.5 : 0.75
                        )
                    )
                    
                    let midRadius = (deadZoneRadius + 4 + currentOuter) / 2.0
                    let rad = centerDeg * .pi / 180.0
                    let iconX = cos(rad) * midRadius
                    let iconY = sin(rad) * midRadius
                    
                    VStack(spacing: 3) {
                        Image(systemName: slice.systemImage)
                            .font(.system(size: isSelected ? 17 : 15, weight: .medium))
                            .foregroundStyle(isSelected ? selectedFg : baseText.opacity(0.90))
                        
                        Text(slice.title.uppercased())
                            .font(.system(size: 8.5, weight: isSelected ? .bold : .semibold, design: .monospaced))
                            .tracking(0.4)
                            .foregroundStyle(isSelected ? selectedFg : baseText.opacity(0.60))
                            .lineLimit(1)
                    }
                    .offset(x: iconX, y: iconY)
                }
                .animation(.easeOut(duration: 0.10), value: selectedIndex)
            }
            
            // Noyau Central Télémétrique
            ZStack {
                Circle()
                    .fill(Color(hex: theme.centerHubHex))
                    .frame(width: deadZoneRadius * 2, height: deadZoneRadius * 2)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                selectedIndex != nil ? hubAccent : baseText.opacity(0.25),
                                lineWidth: 1.0
                            )
                    )
                
                if let idx = selectedIndex, idx < slices.count {
                    VStack(spacing: 1) {
                        Text(String(format: "0%d", idx + 1))
                            .font(.system(size: 7.5, weight: .regular, design: .monospaced))
                            .foregroundStyle(baseText.opacity(0.45))
                        Text(slices[idx].payload.humanReadableShortcut)
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(hubAccent)
                            .lineLimit(1)
                    }
                } else {
                    // Réticule central minimaliste au repos
                    ZStack {
                        Rectangle()
                            .fill(baseText.opacity(0.3))
                            .frame(width: 8, height: 0.75)
                        Rectangle()
                            .fill(baseText.opacity(0.3))
                            .frame(width: 0.75, height: 8)
                    }
                }
            }
            
            // Vecteur d'angle sur le périmètre interne
            if let angleDeg = currentAngleDegrees {
                let indicatorRad = (angleDeg - 90.0) * .pi / 180.0
                let r = deadZoneRadius
                Circle()
                    .fill(hubAccent)
                    .frame(width: 4.5, height: 4.5)
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