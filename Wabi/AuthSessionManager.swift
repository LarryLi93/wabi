import Foundation
import AuthenticationServices
import Combine
import SwiftUI

struct AuthUserProfile: Codable, Equatable {
    var userIdentifier: String
    var fullName: String?
    var email: String?

    var displayName: String {
        if let fullName, !fullName.isEmpty {
            return fullName
        }

        if let email, !email.isEmpty {
            return email
        }

        return "Apple User"
    }

    var initials: String {
        let source = fullName?.isEmpty == false ? fullName! : displayName
        let parts = source
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }

        if !parts.isEmpty {
            return parts.joined()
        }

        return String(displayName.prefix(1)).uppercased()
    }
}

@MainActor
final class AuthSessionManager: ObservableObject {
    @Published var currentUser: AuthUserProfile?
    @Published var isRestoringSession: Bool = false
    @Published var isProcessing: Bool = false
    @Published var lastErrorMessage: String?

    private let keychain = KeychainHelper.shared
    private let shouldRestoreSession: Bool
    private let serviceName = "com.wabi.auth"
    private let accountName = "userProfile"

    init(shouldRestoreSession: Bool = true) {
        self.shouldRestoreSession = shouldRestoreSession
        self.isRestoringSession = shouldRestoreSession

        if shouldRestoreSession {
            Task { @MainActor in
                await restoreSession()
            }
        }
    }

    var isAuthenticated: Bool {
        // This is safe because currentUser is @Published and observed
        currentUser != nil
    }

    func restoreSession() async {
        // Read from keychain is fast, so we can do it immediately
        guard let storedUser = keychain.read(service: serviceName, account: accountName, type: AuthUserProfile.self) else {
            Task { @MainActor in
                self.currentUser = nil
                self.isRestoringSession = false
            }
            return
        }

        // Optimistically set the user to show the main app immediately
        Task { @MainActor in
            self.currentUser = storedUser
            self.isRestoringSession = false
        }

        // Verify the credential state in the background
        Task { @MainActor in
            let credentialState = await credentialState(for: storedUser.userIdentifier)
            switch credentialState {
            case .authorized:
                self.lastErrorMessage = nil
            case .revoked, .notFound:
                self.signOut()
            default:
                break
            }
        }
    }

    func handleAuthorizationResult(_ result: Result<ASAuthorization, Error>) {
        Task { @MainActor in
            self.isProcessing = false
        }
        
        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                Task { @MainActor in self.lastErrorMessage = "apple_sign_in_unavailable" }
                return
            }

            let existingUser = currentUser
            
            // Apple only provides name and email on the first sign in
            let firstName = credential.fullName?.givenName
            let lastName = credential.fullName?.familyName
            
            let fullName: String?
            if let first = firstName, let last = lastName {
                fullName = "\(first) \(last)".trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let first = firstName {
                fullName = first
            } else if let last = lastName {
                fullName = last
            } else {
                fullName = existingUser?.fullName
            }
            
            let email = credential.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? existingUser?.email

            let profile = AuthUserProfile(
                userIdentifier: credential.user,
                fullName: fullName,
                email: email
            )

            persist(profile)
            Task { @MainActor in
                self.currentUser = profile
                self.lastErrorMessage = nil
            }
        case let .failure(error):
            if let authorizationError = error as? ASAuthorizationError, 
               (authorizationError.code == .canceled || authorizationError.code.rawValue == 1001) {
                Task { @MainActor in self.lastErrorMessage = nil }
                return
            }

            Task { @MainActor in self.lastErrorMessage = error.localizedDescription }
        }
    }

    func signOut() {
        keychain.delete(service: serviceName, account: accountName)
        
        // Ensure UI updates happen on the main thread
        Task { @MainActor in
            self.currentUser = nil
            self.lastErrorMessage = nil
            self.isRestoringSession = false
        }
    }

    func clearError() {
        Task { @MainActor in
            self.lastErrorMessage = nil
        }
    }

    func startProcessing() {
        Task { @MainActor in
            self.isProcessing = true
        }
    }

    func applyPreviewUser(_ user: AuthUserProfile?) {
        Task { @MainActor in
            self.currentUser = user
            self.isRestoringSession = false
        }
    }

    private func persist(_ user: AuthUserProfile) {
        keychain.save(user, service: serviceName, account: accountName)
    }

    private func credentialState(for userIdentifier: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userIdentifier) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }
}
