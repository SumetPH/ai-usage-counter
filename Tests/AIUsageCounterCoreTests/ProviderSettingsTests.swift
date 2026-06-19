import XCTest
@testable import AIUsageCounterCore

@MainActor
final class ProviderSettingsTests: XCTestCase {
    func testDisablingMenuProviderFallsBackAndCannotDisableLastProvider() throws {
        let suite = "ProviderSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = ProviderSettings(defaults: defaults)

        settings.setMenuBarProvider(.antigravity)
        XCTAssertTrue(settings.setEnabled(false, for: .antigravity))
        XCTAssertEqual(settings.menuBarProvider, .codex)
        XCTAssertFalse(settings.setEnabled(false, for: .codex))
        XCTAssertEqual(settings.enabledProviders, [.codex])
    }
}
