import Foundation

/// Snapshot of Apple Silicon CPU core clusters and SoC thermal status.
public struct AppleSiliconStats: Sendable, Equatable {
    public let pCoreCount: Int
    public let eCoreCount: Int
    public let pCoreUsageFraction: Double
    public let eCoreUsageFraction: Double
    public let perCoreUsage: [Double]
    public let socTemperatureCelsius: Double?
    public let thermalStateDescription: String

    public init(
        pCoreCount: Int = 0,
        eCoreCount: Int = 0,
        pCoreUsageFraction: Double = 0.0,
        eCoreUsageFraction: Double = 0.0,
        perCoreUsage: [Double] = [],
        socTemperatureCelsius: Double? = nil,
        thermalStateDescription: String = "Nominal"
    ) {
        self.pCoreCount = max(pCoreCount, 0)
        self.eCoreCount = max(eCoreCount, 0)
        self.pCoreUsageFraction = min(max(pCoreUsageFraction, 0.0), 1.0)
        self.eCoreUsageFraction = min(max(eCoreUsageFraction, 0.0), 1.0)
        self.perCoreUsage = perCoreUsage
        self.socTemperatureCelsius = socTemperatureCelsius
        self.thermalStateDescription = thermalStateDescription
    }

    public var formattedTemperature: String {
        guard let temp = socTemperatureCelsius else { return "--°C" }
        return String(format: "%.0f°C", temp)
    }
}
