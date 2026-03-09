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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet
            || urlError.code == .networkConnectionLost
            || urlError.code == .timedOut
            || urlError.code == .cannotConnectToHost {
            throw APIError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw APIError.rateLimited
        }

        guard (200...299).contains(httpResponse.statusCode) else {
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
    // MARK: - Contact Endpoints

    struct ConnectResponse: Decodable {
        let status: String
        let targetHouseholdId: String
        let targetHouseholdName: String
    }

    func connectToHousehold(targetHouseholdId: String) async throws -> ConnectResponse {
        let data = try await authenticatedRequest(
            path: "/households/connect",
            method: "POST",
            body: ["targetHouseholdId": targetHouseholdId]
        )
        return try JSONDecoder().decode(ConnectResponse.self, from: data)
    }

    struct AcceptConnectionResponse: Decodable {
        let status: String
        let fromHouseholdId: String
    }

    func acceptConnection(fromHouseholdId: String) async throws -> AcceptConnectionResponse {
        let data = try await authenticatedRequest(
            path: "/households/connect/accept",
            method: "POST",
            body: ["fromHouseholdId": fromHouseholdId]
        )
        return try JSONDecoder().decode(AcceptConnectionResponse.self, from: data)
    }

    struct ContactsResponse: Decodable {
        let contacts: [ContactEntry]
    }

    struct ContactMember: Decodable {
        let displayName: String
        let plumage: String?
        let crest: String?
        let bio: String?
    }

    struct ContactEntry: Decodable, Identifiable {
        let householdId: String
        let householdName: String
        let status: String
        let direction: String?
        let createdAt: String?
        let connectedAt: String?
        let members: [ContactMember]?
        let lettersSent: Int?
        let lettersReceived: Int?
        let lastLetterAt: String?

        var id: String { householdId }
    }

    func fetchContacts(householdId: String) async throws -> ContactsResponse {
        let data = try await authenticatedRequest(
            path: "/households/contacts/\(householdId)",
            method: "GET"
        )
        return try JSONDecoder().decode(ContactsResponse.self, from: data)
    }

    // MARK: - Mail Endpoints

    struct SendMailResponse: Decodable {
        let messageId: String
    }

    func sendMail(
        targetHouseholdId: String,
        content: String,
        type: String = "text",
        mediaUrl: String? = nil,
        stationery: String = "parchment"
    ) async throws -> SendMailResponse {
        var body: [String: Any] = [
            "targetHouseholdId": targetHouseholdId,
            "content": content,
            "type": type,
            "stationery": stationery,
        ]
        if let mediaUrl {
            body["mediaUrl"] = mediaUrl
        }
        let data = try await authenticatedRequest(
            path: "/mail/send",
            method: "POST",
            body: body
        )
        return try JSONDecoder().decode(SendMailResponse.self, from: data)
    }

    struct MailboxResponse: Decodable {
        let messages: [MailMessage]
        let hasMore: Bool
    }

    struct MailMessage: Decodable, Identifiable {
        let id: String
        let fromUserId: String
        let fromDisplayName: String
        let fromHouseholdId: String
        let fromPlumage: String?
        let fromCrest: String?
        let type: String
        let content: String
        let mediaUrl: String?
        let stationery: String?
        let sentAt: String?
        let isOpened: Bool
        let openedAt: String?
        let openedByUserId: String?
    }

    func fetchMailbox(householdId: String, limit: Int = 20, startAfter: String? = nil, unreadOnly: Bool = false) async throws -> MailboxResponse {
        var path = "/mail/mailbox/\(householdId)?limit=\(limit)"
        if let startAfter {
            path += "&startAfter=\(startAfter)"
        }
        if unreadOnly {
            path += "&unreadOnly=true"
        }
        let data = try await authenticatedRequest(
            path: path,
            method: "GET"
        )
        return try JSONDecoder().decode(MailboxResponse.self, from: data)
    }

    func updateNfcConfigured(householdId: String) async throws {
        _ = try await authenticatedRequest(
            path: "/households/nfc-configured",
            method: "POST",
            body: ["householdId": householdId]
        )
    }

    struct OpenMailResponse: Decodable {
        let message: MailMessage
        let alreadyOpened: Bool
    }

    func openMail(messageId: String, householdId: String) async throws -> OpenMailResponse {
        let data = try await authenticatedRequest(
            path: "/mail/open",
            method: "POST",
            body: ["messageId": messageId, "householdId": householdId]
        )
        return try JSONDecoder().decode(OpenMailResponse.self, from: data)
    }

    // MARK: - User Profile Endpoints

    struct UserStats: Decodable {
        let lettersSent: Int
        let lettersReceived: Int
        let flockMembers: Int
    }

    func fetchStats() async throws -> UserStats {
        let data = try await authenticatedRequest(
            path: "/users/stats",
            method: "GET"
        )
        return try JSONDecoder().decode(UserStats.self, from: data)
    }

    func updateProfile(plumage: String? = nil, crest: String? = nil, bio: String? = nil) async throws {
        var body: [String: Any] = [:]
        if let plumage { body["plumage"] = plumage }
        if let crest { body["crest"] = crest }
        if let bio { body["bio"] = bio }
        guard !body.isEmpty else { return }
        _ = try await authenticatedRequest(
            path: "/users/profile",
            method: "POST",
            body: body
        )
    }

    // MARK: - FCM Endpoints

    func registerFCMToken(token: String, deviceId: String) async throws {
        _ = try await authenticatedRequest(
            path: "/fcm/register",
            method: "POST",
            body: ["token": token, "deviceId": deviceId]
        )
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case notAuthenticated
    case invalidResponse
    case networkError
    case rateLimited
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .notAuthenticated:
            return "You must be signed in to perform this action."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .networkError:
            return "No internet connection. Please check your network and try again."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .serverError(_, let message):
            return message
        }
    }
}
