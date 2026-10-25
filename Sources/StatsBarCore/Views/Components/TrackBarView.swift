import SwiftUI

/// A clean progress track bar rendering filled usage against total capacity track (Law of Closure).
public struct TrackBarView: View {
    public let fraction: Double
    public let height: CGFloat
    public let fillColor: Color
    public let trackColor: Color

    public init(
        fraction: Double,
        height: CGFloat = DesignTokens.Geometry.trackBarHeight,
        fillColor: Color = .accentColor,
        trackColor: Color = DesignTokens.Colors.trackBackground
    ) {
        self.fraction = min(max(fraction, 0.0), 1.0)
        self.height = height
        self.fillColor = fillColor
        self.trackColor = trackColor
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)
                    .frame(height: height)

                Capsule()
                    .fill(fillColor)
                    .frame(width: max(proxy.size.width * CGFloat(fraction), 0), height: height)
            }
        }
        .frame(height: height)
    }
}
