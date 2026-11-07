import SwiftUI

/// Forme géométrique dessinant un secteur annulaire (Donut Slice)
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
                
                // Anneau de fond flouté
                Circle()
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: state.outerRadius * 2 + 8, height: state.outerRadius * 2 + 8)
                
                // Rendu de chaque part du menu radial
                ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                    let isSelected = (state.selectedIndex == index)
                    // Dans SwiftUI, 0° est à 3h. On soustrait 90° pour placer l'index 0 à 12h.
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
                            ? accent.opacity(0.88)
                            : Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.86)
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
                        
                        // Positionnement polaire de l'icône et du label au barycentre du secteur
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
                    .animation(.spring(response: 0.18, dampingFraction: 0.72), value: state.selectedIndex)
                }
                
                // Noyau central (Deadzone + HUD d'information contextuelle)
                ZStack {
                    Circle()
                        .fill(Color(red: 0.05, green: 0.06, blue: 0.09).opacity(0.94))
                        .frame(width: state.deadZoneRadius * 2, height: state.deadZoneRadius * 2)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    state.selectedIndex != nil ? Color.white.opacity(0.35) : Color.red.opacity(0.6),
                                    lineWidth: 1.5
                                )
                        )
                    
                    VStack(spacing: 2) {
                        if let idx = state.selectedIndex, idx < slices.count {
                            Text(slices[idx].title)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 4)
                        } else {
                            Text(state.activeProfile.displayName)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(1)
                            Text("Annuler")
                                .font(.system(size: 8, weight: .regular))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .frame(width: state.deadZoneRadius * 1.8)
                }
                
                // Indicateur vectoriel d'orientation du curseur sur le périmètre de la deadzone
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
}