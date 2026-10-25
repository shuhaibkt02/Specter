import Testing
import SwiftUI
@testable import StatsBarCore

@Suite("DesignTokens and Components Tests")
@MainActor
struct DesignTokensAndComponentsTests {

    @Test("Design tokens satisfy Gestalt and accessibility constraints")
    func testDesignTokensConstraints() {
        // Law of Proximity: inter-card gap >= 1.5x intra-card gap
        #expect(DesignTokens.Spacing.interCardGap >= 1.5 * DesignTokens.Spacing.intraCardGap)

        // Fitts's Law: all interactive hit targets >= 20pt
        #expect(DesignTokens.Geometry.minHitTarget >= 20)
        #expect(DesignTokens.Geometry.actionHitTarget >= 24)

        // Popover width budget strictly 320pt
        #expect(DesignTokens.Geometry.popoverWidth == 320)

        // Corner radii match macOS grouped idioms
        #expect(DesignTokens.Geometry.cardCornerRadius == 10)
        #expect(DesignTokens.Geometry.pillMinHeight >= 22)
    }

    @Test("TrackBarView clamps fraction safely between 0.0 and 1.0")
    func testTrackBarViewClamping() {
        let negative = TrackBarView(fraction: -0.5)
        #expect(negative.fraction == 0.0)

        let excessive = TrackBarView(fraction: 1.5)
        #expect(excessive.fraction == 1.0)

        let nominal = TrackBarView(fraction: 0.65)
        #expect(nominal.fraction == 0.65)
    }

    @Test("SparklineView accepts telemetry arrays without crashing")
    func testSparklineViewInitialization() {
        let empty = SparklineView(values: [])
        #expect(empty.values.isEmpty)

        let single = SparklineView(values: [0.5])
        #expect(single.values.count == 1)

        let multi = SparklineView(values: [0.1, 0.4, 0.8, 0.5])
        #expect(multi.values.count == 4)
        #expect(multi.showLatestPoint == true)
    }

    @Test("CardView initializes standardized 5-slot structure")
    func testCardViewInitialization() {
        let card = CardView(
            title: "CPU",
            value: "32%",
            statusDotColor: DesignTokens.Colors.normal,
            statusText: "Normal"
        )
        #expect(card.title == "CPU")
        #expect(card.value == "32%")
        #expect(card.statusText == "Normal")
        #expect(card.statusDotColor == DesignTokens.Colors.normal)
    }
}
