import SwiftUI

/// Standardized card component enforcing the 5-slot Gestalt grouping contract from Doc 07.
/// No card invents its own layout; all metrics compose into these standardized slots.
public struct CardView<SparklineContent: View, BreakdownContent: View, DetailContent: View>: View {
    public let title: String
    public let value: String
    public let statusDotColor: Color?
    public let statusText: String?
    
    @ViewBuilder public let sparkline: () -> SparklineContent
    @ViewBuilder public let breakdown: () -> BreakdownContent
    @ViewBuilder public let detail: () -> DetailContent

    public init(
        title: String,
        value: String,
        statusDotColor: Color? = nil,
        statusText: String? = nil,
        @ViewBuilder sparkline: @escaping () -> SparklineContent = { EmptyView() },
        @ViewBuilder breakdown: @escaping () -> BreakdownContent = { EmptyView() },
        @ViewBuilder detail: @escaping () -> DetailContent = { EmptyView() }
    ) {
        self.title = title
        self.value = value
        self.statusDotColor = statusDotColor
        self.statusText = statusText
        self.sparkline = sparkline
        self.breakdown = breakdown
        self.detail = detail
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.intraCardGap) {
            // Slot 1: Header (Title, Status, Right-aligned Value)
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(DesignTokens.Typography.cardTitle)
                    .foregroundStyle(.primary)

                if let statusDotColor {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 6, height: 6)
                }

                if let statusText {
                    Text(statusText)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(value)
                    .font(DesignTokens.Typography.cardValue)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            // Slot 2: Sparkline
            let sparklineView = sparkline()
            if !(sparklineView is EmptyView) {
                sparklineView
                    .frame(height: DesignTokens.Geometry.sparklineHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Slot 3: Breakdown
            let breakdownView = breakdown()
            if !(breakdownView is EmptyView) {
                breakdownView
            }

            // Slot 4: Detail / Process List
            let detailView = detail()
            if !(detailView is EmptyView) {
                detailView
            }
        }
        .padding(DesignTokens.Spacing.cardPadding)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Geometry.cardCornerRadius)
                .stroke(DesignTokens.Colors.borderHairline, lineWidth: 1)
        )
    }
}
