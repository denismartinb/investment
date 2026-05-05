import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "La respuesta del servidor no es válida."
        case .unauthorized:
            return "La sesión no es válida o ha caducado."
        case .server(let message):
            return message
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = .shared
        configuration.httpShouldSetCookies = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
        self.decoder = JSONDecoder()
    }

    func login(username: String, password: String) async throws {
        HTTPCookieStorage.shared.cookies?.forEach { cookie in
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }

        var request = URLRequest(url: AppConfiguration.baseURL.appendingPathComponent("api/auth/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "username": username,
            "password": password,
            "next": "/"
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        if http.statusCode == 401 {
            let message = String(data: data, encoding: .utf8) ?? "Credenciales incorrectas."
            throw APIError.server(message.contains("Credenciales incorrectas") ? "Credenciales incorrectas." : message)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server("No se pudo iniciar sesión.")
        }
    }

    func logout() async {
        var request = URLRequest(url: AppConfiguration.baseURL.appendingPathComponent("api/auth/logout"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        _ = try? await session.data(for: request)
        HTTPCookieStorage.shared.cookies?.forEach { cookie in
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }

    func fetchPortfolio() async throws -> PortfolioPayload {
        var request = URLRequest(url: AppConfiguration.baseURL.appendingPathComponent("api/portfolio"))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        if http.statusCode == 401 {
            throw APIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "No se pudo cargar la cartera."
            throw APIError.server(message)
        }
        return try decoder.decode(PortfolioPayload.self, from: data)
    }
}
