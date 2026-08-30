import Combine
import Foundation

@MainActor
final class EmojiUsageStore: ObservableObject {
    private static let defaultsKey = "emojiUsageCounts"

    private let defaults: UserDefaults
    @Published private(set) var counts: [String: Int]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        counts = defaults.dictionary(forKey: Self.defaultsKey)?.reduce(into: [:]) { result, entry in
            guard let count = entry.value as? NSNumber, count.intValue > 0 else { return }
            result[entry.key] = count.intValue
        } ?? [:]
    }

    func recordUse(of emoji: Emoji) {
        counts[emoji.symbol, default: 0] += 1
        defaults.set(counts, forKey: Self.defaultsKey)
    }
}
