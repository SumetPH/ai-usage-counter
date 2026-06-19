import Foundation

let bold = "\u{001B}[1m"
let dim = "\u{001B}[2m"
let reset = "\u{001B}[0m"

func dateText(_ date: Date?) -> String {
    guard let date else { return "unknown" }
    return date.formatted(date: .abbreviated, time: .standard)
}

func windowLines(name: String, window: QuotaWindow, state: UsageState) -> [String] {
    [
        "\(bold)\(name) remaining\(reset): \(window.remainingPercent)%",
        "\(bold)\(name) resets\(reset):    \(dateText(window.resetsAt))",
        "\(bold)Menu value\(reset):       \(state.displayValue(window))",
        "\(dim)Window duration: \(window.durationMinutes.map(String.init) ?? "unknown") minutes\(reset)"
    ]
}

func render(_ state: UsageState) {
    print("\u{001B}[2J\u{001B}[H", terminator: "")
    print("\(bold)AI Usage Counter — THROWAWAY STATE PROTOTYPE\(reset)")
    print("\(dim)Question: can Codex rate-limit windows drive remaining percentages and reset transitions safely?\(reset)\n")
    print("\(bold)MENU BAR\(reset)  ◉  \(state.menuBarText)\(state.isStale ? "  [STALE]" : "")")
    print("\(bold)Connection\(reset): \(state.connection.rawValue)")
    print("\(bold)Refresh\(reset):    \(state.refresh.rawValue)")
    print("\(bold)Clock\(reset):      \(dateText(state.now))")
    if let error = state.lastError { print("\(bold)Message\(reset):    \(error)") }

    if let snapshot = state.snapshot {
        print("\n\(bold)NORMALIZED SNAPSHOT\(reset)  \(dim)source: \(snapshot.source), fetched: \(dateText(snapshot.fetchedAt))\(reset)")
        windowLines(name: "Hourly", window: snapshot.hourly, state: state).forEach { print($0) }
        print("")
        windowLines(name: "Weekly", window: snapshot.weekly, state: state).forEach { print($0) }
    }

    print("\n\(bold)FIXTURES\(reset)")
    print("[1] normal  [2] hourly exhausted  [3] weekly exhausted  [4] both exhausted")
    print("[5] stale   [6] disconnected      [7] reset refresh failure")
    print("\n\(bold)ACTIONS\(reset)")
    print("[t] tick 1 minute  [e] jump past Hourly reset  [r] refresh succeeds  [f] refresh fails")
    print("[l] live Codex probe (opt-in)      [q] quit")
    print("\nChoice: ", terminator: "")
}

var state = Fixture.normal.state(now: Date())

while true {
    render(state)
    guard let choice = readLine()?.lowercased() else { break }
    switch choice {
    case "1": state = reduce(state, .loadFixture(.normal))
    case "2": state = reduce(state, .loadFixture(.hourlyExhausted))
    case "3": state = reduce(state, .loadFixture(.weeklyExhausted))
    case "4": state = reduce(state, .loadFixture(.bothExhausted))
    case "5": state = reduce(state, .loadFixture(.stale))
    case "6": state = reduce(state, .loadFixture(.disconnected))
    case "7": state = reduce(state, .loadFixture(.resetRefreshFailure))
    case "t": state = reduce(state, .tick(seconds: 60))
    case "e":
        if let resetAt = state.snapshot?.hourly.resetsAt {
            state = reduce(state, .tick(seconds: resetAt.timeIntervalSince(state.now) + 1))
            state = reduce(state, .refreshStarted)
        }
    case "r":
        let snapshot = Fixture.normal.state(now: state.now).snapshot!
        state = reduce(state, .refreshSucceeded(snapshot))
    case "f": state = reduce(state, .refreshFailed("Simulated refresh failure"))
    case "l":
        state = reduce(state, .refreshStarted)
        render(state)
        do {
            state = reduce(state, .refreshSucceeded(try CodexRateLimitProbe.fetch()))
        } catch {
            state = reduce(state, .refreshFailed(error.localizedDescription))
        }
    case "q":
        print("\nPrototype stopped. Capture the verdict in NOTES.md before deleting it.")
        exit(0)
    default: break
    }
}
