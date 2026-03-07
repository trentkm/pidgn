//
//  APIService.swift
//  Pidgn
//
//  NOTE: Requires FirebaseAuth package added via SPM in Xcode.

import Foundation
import FirebaseAuth

class APIService {
    static let shared = APIService()

    private let baseURL = "https://adventurous-cat-production.up.railway.app"

    private init() {}

    // MARK: - Authenticated Request

    private func authenticatedRequest(
        path: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        guard let user = Auth.auth().currentUser else {
            throw APIError.notAuthenticated
        }

        let token = try await user.getIDToken()

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to extract error message from response body
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorBody["error"] as? String {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
            }
            throw APIError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Request failed with status \(httpResponse.statusCode)"
            )
        }

        return data
    }

    // MARK: - Household Endpoints

    struct CreateHouseholdResponse: Decodable {
        let householdId: String
    }

    func createHousehold(name: String) async throws -> CreateHouseholdResponse {
        let data = try await authenticatedRequest(
            path: "/households/create",
            method: "POST",
            body: ["name": name]
        )
        return try JSONDecoder().decode(CreateHouseholdResponse.self, from: data)
    }

    struct GenerateInviteResponse: Decodable {
        let inviteCode: String
    }

    func generateInvite(householdId: String) async throws -> GenerateInviteResponse {
        let data = try await authenticatedRequest(
            path: "/households/invite",
            method: "POST",
            body: ["householdId": householdId]
        )
        return try JSONDecoder().decode(GenerateInviteResponse.self, from: data)
    }

    struct JoinHouseholdResponse: Decodable {
        let householdId: String
        let household: HouseholdInfo

        struct HouseholdInfo: Decodable {
            let name: String
            let memberIds: [String]
        }
    }

    func joinHousehold(inviteCode: String) async throws -> JoinHouseholdResponse {
        let data = try await authenticatedRequest(
            path: "/households/join",
            method: "POST",
            body: ["inviteCode": inviteCode]
        )
        return try JSONDecoder().decode(JoinHouseholdResponse.self, from: data)
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case notAuthenticated
    case invalidResponse
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .notAuthenticated:
            return "You must be signed in to perform this action."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .serverError(_, let message):
            return message
        }
    }
}
