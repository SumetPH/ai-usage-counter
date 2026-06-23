import Combine
import Foundation

@MainActor
public final class ProviderSettings: ObservableObject {
    @Published public private(set) var enabledProviders: Set<UsageProviderID>
    @Published public private(set) var menuBarProvider: UsageProviderID
    @Published public private(set) var antigravityModelID: String?

    private let defaults: UserDefaults
    private enum Key {
        static let enabled = "enabledUsageProviders"
        static let menu = "menuBarUsageProvider"
        static let model = "antigravityMenuBarModel"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: Key.enabled)?.compactMap(UsageProviderID.init(rawValue:))
        let enabled: Set<UsageProviderID> = Set(stored ?? [])
        enabledProviders = enabled
        let preferred = defaults.string(forKey: Key.menu).flatMap(UsageProviderID.init(rawValue:)) ?? .codex
        menuBarProvider = enabled.contains(preferred) ? preferred : enabled.sorted(by: Self.providerOrder).first ?? .codex
        antigravityModelID = defaults.string(forKey: Key.model)
    }

    @discardableResult
    public func setEnabled(_ enabled: Bool, for provider: UsageProviderID) -> Bool {
        if enabled {
            enabledProviders.insert(provider)
        } else {
            enabledProviders.remove(provider)
            if menuBarProvider == provider {
                menuBarProvider = enabledProviders.sorted(by: Self.providerOrder).first ?? .codex
            }
        }
        persist()
        return true
    }

    public func setMenuBarProvider(_ provider: UsageProviderID) {
        guard enabledProviders.contains(provider) else { return }
        menuBarProvider = provider
        persist()
    }

    public func setAntigravityModelID(_ id: String?) {
        antigravityModelID = id
        persist()
    }

    private func persist() {
        defaults.set(enabledProviders.map(\.rawValue).sorted(), forKey: Key.enabled)
        defaults.set(menuBarProvider.rawValue, forKey: Key.menu)
        defaults.set(antigravityModelID, forKey: Key.model)
    }

    private static func providerOrder(_ lhs: UsageProviderID, _ rhs: UsageProviderID) -> Bool {
        UsageProviderID.allCases.firstIndex(of: lhs)! < UsageProviderID.allCases.firstIndex(of: rhs)!
    }
}
