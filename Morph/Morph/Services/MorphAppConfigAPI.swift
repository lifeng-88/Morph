import Foundation

struct MorphAppConfigRequest {
    let devId: String
    let source: String?
    let channel: String?
    let version: String
    let afId: String?
    let afAttributionJson: String?

    func toRequestParameters() -> [String: Any] {
        var params: [String: Any] = [
            "dev_id": devId,
            "version": version
        ]
        if let source { params["source"] = source }
        if let channel { params["channel"] = channel }
        if let afId, !afId.isEmpty { params["af_id"] = afId }
        if let afAttributionJson, !afAttributionJson.isEmpty {
            params["af_attribution_json"] = afAttributionJson
        }
        return params
    }
}

struct MorphAppConfigResponse: Decodable {
    let type: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case rechargePresentationType = "recharge_presentation_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fromType = Self.decodeFlexibleInt(from: container, forKey: .type)
        let fromSnake = Self.decodeFlexibleInt(from: container, forKey: .rechargePresentationType)
        type = fromType ?? fromSnake
    }

    private static func decodeFlexibleInt(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Int? {
        if let value = try? container.decode(Int.self, forKey: key) { return value }
        if let raw = try? container.decode(String.self, forKey: key), let value = Int(raw) { return value }
        if let value = try? container.decode(Int32.self, forKey: key) { return Int(value) }
        return nil
    }
}

enum MorphAppConfigPersistence {
    static let presentationTypeKey = "morph.v1.app_config.presentation_type"
    static let fetchSucceededKey = "morph.v1.app_config.fetch_succeeded"
    static let lastRemoteRefreshKey = "morph.v1.app_config.last_remote_refresh"

    static var hasPersistedSuccessfulFetch: Bool {
        UserDefaults.standard.bool(forKey: fetchSucceededKey)
    }

    static func readPersistedPresentationType(defaultValue: Int = 1) -> Int {
        guard let raw = UserDefaults.standard.object(forKey: presentationTypeKey) as? Int else {
            return defaultValue
        }
        return raw == 1 || raw == 2 ? raw : defaultValue
    }

    static func persistSuccessfulPresentationType(_ value: Int) {
        guard value == 1 || value == 2 else { return }
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: presentationTypeKey)
        defaults.set(true, forKey: fetchSucceededKey)
    }
}

enum MorphAppConfigError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid app_config URL"
        case .invalidResponse:
            return "Invalid app_config response"
        case .httpStatus(let code):
            return "app_config HTTP \(code)"
        case .decodingFailed:
            return "Failed to decode app_config"
        }
    }
}

enum MorphAppConfigService {
    static func fetchAppConfig(request: MorphAppConfigRequest) async -> Result<MorphAppConfigResponse, MorphAppConfigError> {
        let base = MorphAPIConfig.effectiveAPIBaseURL
        guard var components = URLComponents(string: base + "/v1/app_config") else {
            return .failure(.invalidURL)
        }

        components.queryItems = request.toRequestParameters().map {
            URLQueryItem(name: $0.key, value: "\($0.value)")
        }

        guard let url = components.url else {
            return .failure(.invalidURL)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 15
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            print("📱 [MorphAppConfig] GET \(url.absoluteString)")
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            guard (200...299).contains(http.statusCode) else {
                return .failure(.httpStatus(http.statusCode))
            }
            let decoded = try JSONDecoder().decode(MorphAppConfigResponse.self, from: data)
            return .success(decoded)
        } catch is DecodingError {
            return .failure(.decodingFailed)
        } catch {
            return .failure(.invalidResponse)
        }
    }
}
