import SwiftUI

/// Continuous 1pt sparkline path with latest-point highlight per Doc 07.
/// Communicates shape over the last 60 seconds with zero visual noise.
public struct SparklineView: View {
    public let values: [Double]
    public let strokeColor: Color
    public let lineWidth: CGFloat
    public let showLatestPoint: Bool

    public init(
        values: [Double],
        strokeColor: Color = .accentColor,
        lineWidth: CGFloat = 1.0,
        showLatestPoint: Bool = true
    ) {
        self.values = values
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
        self.showLatestPoint = showLatestPoint
    }

    public var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }

            let stepX = size.width / CGFloat(max(values.count - 1, 1))
            var path = Path()
            var latestPoint: CGPoint?

            for (index, value) in values.enumerated() {
                let clamped = min(max(value, 0.0), 1.0)
                let x = CGFloat(index) * stepX
                let y = size.height * (1.0 - CGFloat(clamped))

                let point = CGPoint(x: x, y: y)
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }

                if index == values.count - 1 {
                    latestPoint = point
                }
            }

            context.stroke(path, with: .color(strokeColor), lineWidth: lineWidth)

            if showLatestPoint, let latest = latestPoint {
                let dotRect = CGRect(x: latest.x - 2, y: latest.y - 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: dotRect), with: .color(strokeColor))
            }
        }
    }
}
