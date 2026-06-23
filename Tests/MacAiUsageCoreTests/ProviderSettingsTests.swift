import XCTest
@testable import MacAiUsageCore

@MainActor
final class ProviderSettingsTests: XCTestCase {
    func testDisablingMenuProviderFallsBackAndAllowsDisablingAll() throws {
        let suite = "ProviderSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = ProviderSettings(defaults: defaults)

        // Enable both first
        XCTAssertTrue(settings.setEnabled(true, for: .codex))
        XCTAssertTrue(settings.setEnabled(true, for: .antigravity))

        settings.setMenuBarProvider(.antigravity)
        XCTAssertEqual(settings.menuBarProvider, .antigravity)

        // Disabling the menu bar provider falls back to the next available one (codex)
        XCTAssertTrue(settings.setEnabled(false, for: .antigravity))
        XCTAssertEqual(settings.menuBarProvider, .codex)

        // Disabling all providers is allowed
        XCTAssertTrue(settings.setEnabled(false, for: .codex))
        XCTAssertEqual(settings.enabledProviders, [])
    }
}
