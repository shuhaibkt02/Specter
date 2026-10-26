import SwiftUI

/// Unified Design System Tokens strictly adhering to Doc 07 specification.
/// Enforces an 8pt spatial grid, fixed 320pt popover width, 10pt corner radii,
/// and semantic typography and color conventions.
public enum DesignTokens {
    public enum Spacing {
        public static let xxSmall: CGFloat = 2
        public static let xSmall: CGFloat = 4
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let xLarge: CGFloat = 24

        /// Inter-card gap must be >= 1.5x intra-card gap per Law of Proximity
        public static let interCardGap: CGFloat = 12
        public static let intraCardGap: CGFloat = 6
        public static let cardPadding: CGFloat = 14
        public static let popoverPadding: CGFloat = 12
    }

    public enum Geometry {
        public static let popoverWidth: CGFloat = 320
        public static let popoverTwoColumnWidth: CGFloat = 590
        public static let vitalsColumnWidth: CGFloat = 275
        public static let inspectorColumnWidth: CGFloat = 303
        public static let popoverMaxHeight: CGFloat = 560
        public static let cardCornerRadius: CGFloat = 10
        public static let popoverCornerRadius: CGFloat = 10
        public static let pillCornerRadius: CGFloat = 5
        public static let trackBarCornerRadius: CGFloat = 3

        public static let pillMinHeight: CGFloat = 22
        public static let trackBarHeight: CGFloat = 6
        public static let sparklineHeight: CGFloat = 36
        public static let minHitTarget: CGFloat = 20
        public static let actionHitTarget: CGFloat = 24
    }

    public enum Typography {
        public static let pill = Font.system(size: 11, weight: .medium, design: .default)
        public static let cardTitle = Font.system(size: 13, weight: .semibold, design: .default)
        public static let cardValue = Font.system(size: 14, weight: .semibold, design: .default)
        public static let body = Font.system(size: 12, weight: .regular, design: .default)
        public static let caption = Font.system(size: 11, weight: .regular, design: .default)
        public static let captionSecondary = Font.system(size: 10, weight: .medium, design: .default)
    }

    public enum Colors {
        public static let borderHairline = Color.primary.opacity(0.12)
        public static let trackBackground = Color.secondary.opacity(0.15)
        public static let hoverBackground = Color.primary.opacity(0.06)

        // Semantic colors - reserved for exceptions only per Von Restorff Effect
        public static let normal = Color.green
        public static let warning = Color.orange
        public static let critical = Color.red
    }
}
