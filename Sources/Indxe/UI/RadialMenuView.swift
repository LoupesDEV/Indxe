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
    
    private let canvasSize: CGFloat = 320.0
    
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
                        innerRadius: deadZoneRadius + 5,
                        outerRadius: currentOuter
                    )
                    .fill(isSelected ? activeFill : inactiveFill.opacity(0.94))
                    .overlay(
                        AnnularSectorShape(
                            startAngle: .degrees(startDeg),
                            endAngle: .degrees(endDeg),
                            innerRadius: deadZoneRadius + 5,
                            outerRadius: currentOuter
                        )
                        .stroke(
                            isSelected ? activeFill : baseText.opacity(theme.borderOpacity),
                            lineWidth: 1.0
                        )
                    )
                    
                    let midRadius = (deadZoneRadius + 5 + currentOuter) / 2.0
                    let rad = centerDeg * .pi / 180.0
                    let iconX = cos(rad) * midRadius
                    let iconY = sin(rad) * midRadius
                    
                    VStack(spacing: 4) {
                        Image(systemName: slice.systemImage)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(isSelected ? selectedFg : baseText.opacity(0.9))
                        
                        Text(slice.title)
                            .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? selectedFg : baseText.opacity(0.65))
                            .lineLimit(1)
                    }
                    .offset(x: iconX, y: iconY)
                }
                .animation(.easeOut(duration: 0.12), value: selectedIndex)
            }
            
            // Centre épuré
            Circle()
                .fill(Color(hex: theme.centerHubHex).opacity(0.95))
                .frame(width: deadZoneRadius * 2, height: deadZoneRadius * 2)
                .overlay(
                    Circle()
                        .strokeBorder(
                            selectedIndex != nil ? hubAccent.opacity(0.8) : baseText.opacity(0.15),
                            lineWidth: 1.0
                        )
                )
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