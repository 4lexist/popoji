import Combine
import Foundation

enum SkinTone: String, CaseIterable, Identifiable {
    case neutral
    case light
    case mediumLight
    case medium
    case mediumDark
    case dark

    var id: String { rawValue }

    var name: String {
        switch self {
        case .neutral: "Neutral"
        case .light: "Light"
        case .mediumLight: "Medium-light"
        case .medium: "Medium"
        case .mediumDark: "Medium-dark"
        case .dark: "Dark"
        }
    }

    var preview: String {
        applying(to: "👍")
    }

    private var modifier: Unicode.Scalar? {
        switch self {
        case .neutral: nil
        case .light: Unicode.Scalar(0x1F3FB)
        case .mediumLight: Unicode.Scalar(0x1F3FC)
        case .medium: Unicode.Scalar(0x1F3FD)
        case .mediumDark: Unicode.Scalar(0x1F3FE)
        case .dark: Unicode.Scalar(0x1F3FF)
        }
    }

    func applying(to symbol: String) -> String {
        let neutralScalars = Array(
            symbol.unicodeScalars.filter { !$0.properties.isEmojiModifier }
        )
        let neutralSymbol = neutralScalars.reduce(into: "") { result, scalar in
            result.unicodeScalars.append(scalar)
        }
        guard let modifier else {
            return neutralSymbol
        }

        var result = ""
        var index = 0

        while index < neutralScalars.count {
            let scalar = neutralScalars[index]
            result.unicodeScalars.append(scalar)

            guard scalar.properties.isEmojiModifierBase else {
                index += 1
                continue
            }

            // In person-holding-hands sequences, the people receive the chosen
            // tone; modifying the handshake in the middle would break the ZWJ
            // sequence. A standalone handshake still receives the tone.
            let isHandshakeInSequence = scalar.value == 0x1F91D
                && neutralScalars.contains { $0.value == 0x200D }

            if !isHandshakeInSequence {
                // Keep an emoji presentation selector attached to its base and
                // place the skin-tone modifier after it (for example, ✌️🏽).
                if index + 1 < neutralScalars.count,
                   neutralScalars[index + 1].value == 0xFE0F {
                    result.unicodeScalars.append(neutralScalars[index + 1])
                    index += 1
                }
                result.unicodeScalars.append(modifier)
            }

            index += 1
        }

        return result
    }
}

@MainActor
final class SkinToneStore: ObservableObject {
    private static let defaultsKey = "skinTone"

    private let defaults: UserDefaults
    @Published var selected: SkinTone {
        didSet {
            defaults.set(selected.rawValue, forKey: Self.defaultsKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selected = defaults.string(forKey: Self.defaultsKey)
            .flatMap(SkinTone.init(rawValue:)) ?? .neutral
    }
}
