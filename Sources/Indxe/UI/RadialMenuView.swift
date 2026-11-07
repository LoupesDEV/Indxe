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
    
    private let canvasSize: CGFloat = 340.0
    private let gapDegrees: Double = 3.0
    
    var body: some View {
        ZStack {
            if state.isVisible {
                let slices = state.activeProfile.slices
                let count = slices.count
                let sectorStep = 360.0 / Double(max(count, 1))
                
                Circle()
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: state.outerRadius * 2 + 8, height: state.outerRadius * 2 + 8)
                
                ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                    let isSelected = (state.selectedIndex == index)
                    let centerDeg = Double(index) * sectorStep - 90.0
                    let startDeg = centerDeg - (sectorStep / 2.0) + (gapDegrees / 2.0)
                    let endDeg = centerDeg + (sectorStep / 2.0) - (gapDegrees / 2.0)
                    
                    let accent = Color(hex: slice.accentColorHex)
                    
                    ZStack {
                        AnnularSectorShape(
                            startAngle: .degrees(startDeg),
                            endAngle: .degrees(endDeg),
                            innerRadius: state.deadZoneRadius + 6,
                            outerRadius: isSelected ? state.outerRadius + 8 : state.outerRadius
                        )
                        .fill(
                            isSelected
                            ? accent.opacity(0.90)
                            : Color(red: 0.05, green: 0.07, blue: 0.09).opacity(0.88)
                        )
                        .overlay(
                            AnnularSectorShape(
                                startAngle: .degrees(startDeg),
                                endAngle: .degrees(endDeg),
                                innerRadius: state.deadZoneRadius + 6,
                                outerRadius: isSelected ? state.outerRadius + 8 : state.outerRadius
                            )
                            .stroke(
                                isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.14),
                                lineWidth: isSelected ? 2.0 : 1.0
                            )
                        )
                        
                        let midRadius = (state.deadZoneRadius + 6 + (isSelected ? state.outerRadius + 8 : state.outerRadius)) / 2.0
                        let rad = centerDeg * .pi / 180.0
                        let iconX = cos(rad) * midRadius
                        let iconY = sin(rad) * midRadius
                        
                        VStack(spacing: 4) {
                            Image(systemName: slice.systemImage)
                                .font(.system(size: isSelected ? 20 : 17, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                            
                            Text(slice.title)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(isSelected ? .white : .white.opacity(0.65))
                                .lineLimit(1)
                        }
                        .offset(x: iconX, y: iconY)
                    }
                    .animation(.spring(response: 0.16, dampingFraction: 0.75), value: state.selectedIndex)
                }
                
                // Noyau central
                ZStack {
                    Circle()
                        .fill(Color(red: 0.05, green: 0.06, blue: 0.09).opacity(0.95))
                        .frame(width: state.deadZoneRadius * 2, height: state.deadZoneRadius * 2)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    state.selectedIndex != nil ? Color.white.opacity(0.35) : Color(hex: 0xDC2626).opacity(0.75),
                                    lineWidth: 1.5
                                )
                        )
                    
                    VStack(spacing: 2) {
                        if let idx = state.selectedIndex, idx < slices.count {
                            Text(slices[idx].title)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(slices[idx].payload.humanReadableShortcut)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.65))
                                .lineLimit(1)
                        } else {
                            Text(state.activeProfile.displayName)
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                            Text("Relâcher = Annuler")
                                .font(.system(size: 7, weight: .regular))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    .frame(width: state.deadZoneRadius * 1.8)
                }
                
                if let angleDeg = state.currentAngleDegrees {
                    let indicatorRad = (angleDeg - 90.0) * .pi / 180.0
                    let r = state.deadZoneRadius + 1
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .offset(x: cos(indicatorRad) * r, y: sin(indicatorRad) * r)
                }
            }
        }
        .frame(width: canvasSize, height: canvasSize)
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