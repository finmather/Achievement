import Foundation

/// A 64-bit SteamID identifying an individual Steam account.
public struct SteamID: Hashable, Sendable, CustomStringConvertible {
    /// The lowest SteamID64 an individual (public-universe) account can have.
    public static let individualAccountBase: UInt64 = 76_561_197_960_265_728

    public let rawValue: UInt64

    public init?(rawValue: UInt64) {
        guard rawValue >= Self.individualAccountBase else { return nil }
        self.rawValue = rawValue
    }

    public init?(string: String) {
        guard let value = UInt64(string.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        self.init(rawValue: value)
    }

    public var description: String { String(rawValue) }

    public var communityProfileURL: URL {
        URL(string: "https://steamcommunity.com/profiles/\(rawValue)")!
    }
}

extension SteamID: Codable {
    // Steam's JSON APIs return SteamIDs as strings; our own cache stores them as
    // numbers. Accept both.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw: UInt64
        if let value = try? container.decode(UInt64.self) {
            raw = value
        } else {
            let string = try container.decode(String.self)
            guard let value = UInt64(string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Not a SteamID64: \(string)"
                )
            }
            raw = value
        }
        guard let id = SteamID(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "SteamID64 out of individual-account range: \(raw)"
            )
        }
        self = id
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
