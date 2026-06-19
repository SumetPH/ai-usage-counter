import Foundation

public actor CodexAppServerProvider: UsageProviding {
    private let locator: CodexExecutableLocator
    private var connection: AppServerConnection?
    private var readerTask: Task<Void, Never>?
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    private var nextRequestID = 1
    private var updateContinuations: [UUID: AsyncStream<UsageSnapshot>.Continuation] = [:]
    private var hasFetchedSnapshot = false
    private var shuttingDown = false

    public init(locator: CodexExecutableLocator = CodexExecutableLocator()) {
        self.locator = locator
    }

    public func fetchSnapshot() async throws -> UsageSnapshot {
        try await ensureConnected()
        let timeout: TimeInterval = hasFetchedSnapshot ? 12 : 30
        let data = try await request(method: "account/rateLimits/read", params: NSNull(), timeout: timeout)
        let snapshot = try RateLimitDecoder.decodeResponse(data)
        hasFetchedSnapshot = true
        return snapshot
    }

    public func updates() async -> AsyncStream<UsageSnapshot> {
        let id = UUID()
        return AsyncStream { continuation in
            updateContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeUpdateContinuation(id) }
            }
        }
    }

    public func shutdown() async {
        shuttingDown = true
        readerTask?.cancel()
        readerTask = nil
        connection?.stop()
        connection = nil
        failPending(with: UsageProviderError.transportClosed)
        updateContinuations.values.forEach { $0.finish() }
        updateContinuations.removeAll()
    }

    private func ensureConnected() async throws {
        if connection != nil { return }
        guard let executable = locator.locate() else {
            throw UsageProviderError.executableNotFound
        }

        shuttingDown = false
        let newConnection = AppServerConnection(executableURL: executable)
        let stream: AsyncStream<Data>
        do {
            stream = try newConnection.start()
        } catch {
            throw UsageProviderError.launchFailed(error.localizedDescription)
        }
        connection = newConnection
        readerTask = Task { [weak self] in
            for await line in stream {
                await self?.receive(line)
            }
            await self?.connectionDidClose()
        }

        do {
            _ = try await request(
                method: "initialize",
                params: [
                    "clientInfo": [
                        "name": "ai_usage_counter",
                        "title": "AI Usage Counter",
                        "version": "1.0.0",
                    ],
                ],
                timeout: 10
            )
            try sendNotification(method: "initialized", params: [:])
        } catch {
            newConnection.stop()
            connection = nil
            throw error
        }
    }

    private func request(method: String, params: Any, timeout: TimeInterval) async throws -> Data {
        guard let connection else { throw UsageProviderError.transportClosed }
        let id = nextRequestID
        nextRequestID += 1
        let payload: [String: Any] = ["method": method, "id": id, "params": params]
        let data = try JSONSerialization.data(withJSONObject: payload)

        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            do {
                try connection.send(data)
            } catch {
                pending.removeValue(forKey: id)
                continuation.resume(throwing: UsageProviderError.transportClosed)
                return
            }
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                await self?.timeOutRequest(id)
            }
        }
    }

    private func sendNotification(method: String, params: Any) throws {
        guard let connection else { throw UsageProviderError.transportClosed }
        let data = try JSONSerialization.data(withJSONObject: ["method": method, "params": params])
        try connection.send(data)
    }

    private func receive(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let id = (object["id"] as? NSNumber)?.intValue,
           let continuation = pending.removeValue(forKey: id) {
            continuation.resume(returning: data)
            return
        }
        guard object["method"] as? String == "account/rateLimits/updated" else { return }

        if let snapshot = try? RateLimitDecoder.decodeUpdate(data) {
            publish(snapshot)
        } else {
            Task { [weak self] in
                guard let self, let snapshot = try? await self.fetchSnapshot() else { return }
                await self.publish(snapshot)
            }
        }
    }

    private func publish(_ snapshot: UsageSnapshot) {
        updateContinuations.values.forEach { $0.yield(snapshot) }
    }

    private func timeOutRequest(_ id: Int) {
        guard let continuation = pending.removeValue(forKey: id) else { return }
        continuation.resume(throwing: UsageProviderError.timedOut)
    }

    private func connectionDidClose() {
        connection = nil
        readerTask = nil
        if !shuttingDown {
            failPending(with: UsageProviderError.transportClosed)
        }
    }

    private func failPending(with error: Error) {
        let values = pending.values
        pending.removeAll()
        values.forEach { $0.resume(throwing: error) }
    }

    private func removeUpdateContinuation(_ id: UUID) {
        updateContinuations.removeValue(forKey: id)
    }
}

private final class AppServerConnection: @unchecked Sendable {
    private let executableURL: URL
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let errors = Pipe()
    private let lock = NSLock()
    private var buffer = Data()
    private var continuation: AsyncStream<Data>.Continuation?

    init(executableURL: URL) {
        self.executableURL = executableURL
    }

    func start() throws -> AsyncStream<Data> {
        let stream = AsyncStream<Data> { continuation in
            self.continuation = continuation
        }
        process.executableURL = executableURL
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.consume(data)
        }
        process.terminationHandler = { [weak self] _ in self?.finish() }
        try process.run()
        return stream
    }

    func send(_ data: Data) throws {
        guard process.isRunning else { throw UsageProviderError.transportClosed }
        input.fileHandleForWriting.write(data)
        input.fileHandleForWriting.write(Data([0x0A]))
    }

    func stop() {
        output.fileHandleForReading.readabilityHandler = nil
        if process.isRunning { process.terminate() }
        input.fileHandleForWriting.closeFile()
        finish()
    }

    private func consume(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            if !line.isEmpty { continuation?.yield(line) }
        }
    }

    private func finish() {
        lock.lock()
        defer { lock.unlock() }
        continuation?.finish()
        continuation = nil
    }
}
