import Combine
import Foundation

struct ExcludedApplication: Codable, Hashable, Identifiable {
    let bundleIdentifier: String
    let displayName: String

    var id: String { bundleIdentifier }
}

@MainActor
final class AppExclusionStore: ObservableObject {
    private static let defaultsKey = "excludedApplications"

    @Published private(set) var applications: [ExcludedApplication]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let saved = try? JSONDecoder().decode([ExcludedApplication].self, from: data)
        else {
            applications = []
            return
        }
        applications = saved.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    var bundleIdentifiers: Set<String> {
        Set(applications.map(\.bundleIdentifier))
    }

    func contains(bundleIdentifier: String) -> Bool {
        applications.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    func exclude(_ application: ExcludedApplication) {
        applications.removeAll { $0.bundleIdentifier == application.bundleIdentifier }
        applications.append(application)
        sortAndSave()
    }

    func include(bundleIdentifier: String) {
        applications.removeAll { $0.bundleIdentifier == bundleIdentifier }
        sortAndSave()
    }

    private func sortAndSave() {
        applications.sort {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        if let data = try? JSONEncoder().encode(applications) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
