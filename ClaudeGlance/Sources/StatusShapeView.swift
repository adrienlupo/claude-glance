import SwiftUI

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

struct StatusShapeView: View {
    let status: SessionStatus
    let size: CGFloat

    @AppStorage("useShapesForStatus") private var useShapes = false

    var body: some View {
        if useShapes {
            shapedIndicator
        } else {
            Circle()
                .fill(status.color)
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private var shapedIndicator: some View {
        switch status {
        case .idle:
            Circle()
                .fill(status.color)
                .frame(width: size, height: size)
        case .busy:
            TriangleShape()
                .fill(status.color)
                .frame(width: size, height: size)
        case .waiting:
            RoundedRectangle(cornerRadius: size * 0.15)
                .fill(status.color)
                .frame(width: size, height: size)
        }
    }
}
