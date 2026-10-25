import SwiftUI
import StatsBarCore

/// Minimalist sparkline path for rendering recent telemetry history.
/// Wireframe placeholder: can be fully restyled during the dedicated UI/UX phase.
public struct SparklineView: View {
    public let values: [Double]
    public let strokeColor: Color
    public let lineWidth: CGFloat

    public init(values: [Double], strokeColor: Color = .accentColor, lineWidth: CGFloat = 1.5) {
        self.values = values
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
    }

    public var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }

            let stepX = size.width / CGFloat(max(values.count - 1, 1))
            var path = Path()

            for (index, value) in values.enumerated() {
                let clamped = min(max(value, 0.0), 1.0)
                let x = CGFloat(index) * stepX
                let y = size.height * (1.0 - CGFloat(clamped))

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(path, with: .color(strokeColor), lineWidth: lineWidth)
        }
    }
}
