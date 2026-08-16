import Foundation

public struct AppConfiguration: Sendable, Equatable {
    public let openRouterAPIKey: String?
    public let openRouterModel: String
    public let openRouterRequestTimeoutSeconds: Double
    public let openRouterTemperature: Double
    public let logLevel: LogLevel

    public init(
        openRouterAPIKey: String?,
        openRouterModel: String,
        openRouterRequestTimeoutSeconds: Double,
        openRouterTemperature: Double,
        logLevel: LogLevel
    ) {
        self.openRouterAPIKey = openRouterAPIKey
        self.openRouterModel = openRouterModel
        self.openRouterRequestTimeoutSeconds = openRouterRequestTimeoutSeconds
        self.openRouterTemperature = openRouterTemperature
        self.logLevel = logLevel
    }

    public static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppConfiguration {

        let level: LogLevel

        switch environment["ARIA_LOG_LEVEL"]?.lowercased() {
        case "debug":
            level = .debug
        case "warning":
            level = .warning
        case "error":
            level = .error
        default:
            level = .info
        }

        let timeout =
            environment["OPENROUTER_REQUEST_TIMEOUT_SECONDS"]
            .flatMap(Double.init) ?? 60.0

        let temperature =
            environment["OPENROUTER_TEMPERATURE"]
            .flatMap(Double.init) ?? 0.8

        return AppConfiguration(
            openRouterAPIKey: environment["OPENROUTER_API_KEY"],
            openRouterModel:
                environment["OPENROUTER_MODEL"]
                ?? "openai/gpt-oss-20b:free",
            openRouterRequestTimeoutSeconds: timeout,
            openRouterTemperature: temperature,
            logLevel: level
        )
    }
}
