//
//  AuthService.swift
//  Pidgn
//
//  NOTE: Requires FirebaseAuth and FirebaseFirestore packages added via SPM in Xcode.

import Foundation
import Observation
import FirebaseAuth
import FirebaseFirestore

@MainActor
@Observable
class AuthService {
    var user: User?
    var isAuthenticated = false
    var isLoading = true
    var errorMessage: String?
    var userProfile: UserProfile?

    nonisolated(unsafe) private var authStateListener: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()

    struct UserProfile {    
        let uid: String
        let displayName: String
        let email: String
        let householdId: String?
    }

    init() {
        listenToAuthState()
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Auth State Listener

    private func listenToAuthState() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.user = user
                self.isAuthenticated = user != nil

                if let user {
                    await self.fetchUserProfile(uid: user.uid)
                } else {
                    self.userProfile = nil
                }

                self.isLoading = false
            }
        }
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String, displayName: String) async {
        errorMessage = nil
        isLoading = true

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()

            let userData: [String: Any] = [
                "uid": result.user.uid,
                "displayName": displayName,
                "email": email,
                "createdAt": FieldValue.serverTimestamp()
            ]
            try await db.collection("users").document(result.user.uid).setData(userData)

            await fetchUserProfile(uid: result.user.uid)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async {
        errorMessage = nil
        isLoading = true

        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() {
        errorMessage = nil
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - ID Token

    func getIDToken() async -> String? {
        do {
            return try await user?.getIDToken()
        } catch {
            errorMessage = "Failed to get auth token: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - User Profile

    func fetchUserProfile(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            guard let data = document.data() else { return }

            userProfile = UserProfile(
                uid: uid,
                displayName: data["displayName"] as? String ?? "",
                email: data["email"] as? String ?? "",
                householdId: data["householdId"] as? String
            )
        } catch {
            print("Failed to fetch user profile: \(error.localizedDescription)")
        }
    }

    func refreshProfile() async {
        guard let uid = user?.uid else { return }
        await fetchUserProfile(uid: uid)
    }
}
