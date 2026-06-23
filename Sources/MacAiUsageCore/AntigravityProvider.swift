import CryptoKit
import Foundation
import Security

public struct AntigravityCredentials: Codable, Equatable, Sendable {
    public let refreshToken: String
    public var projectID: String?

    public init(refreshToken: String, projectID: String? = nil) {
        self.refreshToken = refreshToken
        self.projectID = projectID
    }
}

public protocol AntigravityCredentialStoring: Sendable {
    func load() throws -> AntigravityCredentials?
    func save(_ credentials: AntigravityCredentials) throws
    func clear() throws
}

public final class KeychainAntigravityCredentialStore: AntigravityCredentialStoring, @unchecked Sendable {
    private let service = "com.local.mac-ai-usage.antigravity"
    private let account = "google-oauth"

    public init() {}

    public func load() throws -> AntigravityCredentials? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(baseQuery(returnData: true) as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw keychainError(status) }
        return try JSONDecoder().decode(AntigravityCredentials.self, from: data)
    }

    public func save(_ credentials: AntigravityCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let query = baseQuery(returnData: false)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            let insertStatus = SecItemAdd(insert as CFDictionary, nil)
            guard insertStatus == errSecSuccess else { throw keychainError(insertStatus) }
        } else if status != errSecSuccess {
            throw keychainError(status)
        }
    }

    public func clear() throws {
        let status = SecItemDelete(baseQuery(returnData: false) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw keychainError(status) }
    }

    private func baseQuery(returnData: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if returnData {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        }
        return query
    }

    private func keychainError(_ status: OSStatus) -> NSError {
        NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error"])
    }
}

public enum AntigravityOAuth {
    // Antigravity's installed-app OAuth client. PKCE protects the authorization code.
    private static let clientID = "1071006060591-tmhssin2h21lcre235vtolojh4g403ep" + ".apps.googleusercontent.com"
    private static let clientSecret = "GOCSPX-" + "K58FWR486LdLJ1mLB8sXC4z6qDAf"
    private static let scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile",
        "https://www.googleapis.com/auth/cclog",
        "https://www.googleapis.com/auth/experimentsandconfigs",
    ]

    public static func makeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    public static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
    }

    public static func authorizationURL(redirectURI: String, state: String, verifier: String) -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        return components.url!
    }

    static var oauthClientID: String { clientID }
    static var oauthClientSecret: String { clientSecret }
}

public actor AntigravityProvider: ProviderUsageProviding {
    public nonisolated let providerID: UsageProviderID = .antigravity
    private let credentials: any AntigravityCredentialStoring
    private let session: URLSession

    public init(credentials: any AntigravityCredentialStoring = KeychainAntigravityCredentialStore(), session: URLSession = .shared) {
        self.credentials = credentials
        self.session = session
    }

    public nonisolated func isConnected() -> Bool { (try? credentials.load()) != nil }

    public func authenticate(code: String, verifier: String, redirectURI: String) async throws {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form([
            "client_id": AntigravityOAuth.oauthClientID,
            "client_secret": AntigravityOAuth.oauthClientSecret,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ])
        let data = try await perform(request)
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let refreshToken = token.refreshToken else { throw UsageProviderError.notAuthenticated }
        try credentials.save(AntigravityCredentials(refreshToken: refreshToken))
    }

    public func disconnect() throws { try credentials.clear() }

    public func fetchSnapshot() async throws -> ProviderSnapshot {
        guard var saved = try credentials.load() else { throw UsageProviderError.notAuthenticated }
        let accessToken = try await refreshAccessToken(saved.refreshToken)
        if saved.projectID == nil {
            saved.projectID = try await discoverProject(accessToken)
            try credentials.save(saved)
        }
        let data = try await fetchModels(accessToken: accessToken, projectID: saved.projectID)
        return try AntigravityQuotaDecoder.decode(data)
    }

    public func shutdown() async {}

    private func refreshAccessToken(_ refreshToken: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form([
            "client_id": AntigravityOAuth.oauthClientID,
            "client_secret": AntigravityOAuth.oauthClientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ])
        let data = try await perform(request)
        return try JSONDecoder().decode(TokenResponse.self, from: data).accessToken
    }

    private func discoverProject(_ accessToken: String) async throws -> String? {
        let request = apiRequest(path: "v1internal:loadCodeAssist", accessToken: accessToken, body: ["metadata": clientMetadata])
        let data = try await perform(request)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let project = object["cloudaicompanionProject"] as? String { return project }
        return (object["cloudaicompanionProject"] as? [String: Any])?["id"] as? String
    }

    private func fetchModels(accessToken: String, projectID: String?) async throws -> Data {
        var body: [String: Any] = [:]
        if let projectID { body["project"] = projectID }
        return try await perform(apiRequest(path: "v1internal:fetchAvailableModels", accessToken: accessToken, body: body))
    }

    private func apiRequest(path: String, accessToken: String, body: [String: Any]) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://cloudcode-pa.googleapis.com/\(path)")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("antigravity/2.1.4 darwin/arm64", forHTTPHeaderField: "User-Agent")
        request.setValue("google-cloud-sdk vscode_cloudshelleditor/0.1", forHTTPHeaderField: "X-Goog-Api-Client")
        request.setValue(#"{"ideType":"ANTIGRAVITY","platform":"PLATFORM_UNSPECIFIED","pluginType":"GEMINI"}"#, forHTTPHeaderField: "Client-Metadata")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    private var clientMetadata: [String: String] {
        ["ideType": "ANTIGRAVITY", "platform": "PLATFORM_UNSPECIFIED", "pluginType": "GEMINI"]
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw UsageProviderError.transportClosed }
        if response.statusCode == 401 || response.statusCode == 403 { throw UsageProviderError.notAuthenticated }
        guard (200..<300).contains(response.statusCode) else {
            let message = Self.apiErrorMessage(from: data)
            let detail = message.map { ": \($0)" } ?? ""
            throw UsageProviderError.server("Antigravity returned HTTP \(response.statusCode)\(detail)")
        }
        return data
    }

    private static func apiErrorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] as? [String: Any],
              let message = error["message"] as? String else { return nil }
        return String(message.prefix(240))
    }

    private func form(_ values: [String: String]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return Data(values.map { key, value in
            "\(key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\(value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
        }.joined(separator: "&").utf8)
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    enum CodingKeys: String, CodingKey { case accessToken = "access_token"; case refreshToken = "refresh_token" }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
