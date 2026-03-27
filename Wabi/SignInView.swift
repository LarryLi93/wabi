import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var authManager: AuthSessionManager

    var body: some View {
        ZStack {
            WabiTheme.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 48)

                    VStack(alignment: .leading, spacing: 32) {
                        heroSection
                        signInSection
                    }
                    .padding(32)
                    .background(cardBackground)
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Text(text("app_title"))
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(WabiTheme.textPrimary)

            Spacer()

            Menu {
                Button("English") {
                    localizationManager.setLanguage("en")
                }

                Button("中文") {
                    localizationManager.setLanguage("zh")
                }
            } label: {
                Image(systemName: "globe")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WabiTheme.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(WabiTheme.surface)
                            .overlay(
                                Circle()
                                    .stroke(WabiTheme.border.opacity(0.45), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(text("sign_in_title"))
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(WabiTheme.textPrimary)

            Text(text("sign_in_subtitle"))
                .font(.system(size: 16))
                .foregroundStyle(WabiTheme.textSecondary)

            Text(text("sign_in_privacy"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WabiTheme.textMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(WabiTheme.surface)
                        .overlay(
                            Capsule()
                                .stroke(WabiTheme.border.opacity(0.45), lineWidth: 1)
                        )
                )
        }
    }

    private var signInSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let lastErrorMessage = authManager.lastErrorMessage, !lastErrorMessage.isEmpty {
                Text(resolvedErrorMessage(lastErrorMessage))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.red.opacity(0.08))
                    )
            }

            ZStack {
                SignInWithAppleButton(.continue) { request in
                    authManager.clearError()
                    authManager.startProcessing()
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    authManager.handleAuthorizationResult(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .opacity(authManager.isProcessing ? 0.5 : 1.0)
                .disabled(authManager.isProcessing)

                if authManager.isProcessing {
                    ProgressView()
                        .tint(.white)
                }
            }

            Text(text("sign_in_button_hint"))
                .font(.system(size: 12))
                .foregroundStyle(WabiTheme.textMuted)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(WabiTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(WabiTheme.border.opacity(0.45), lineWidth: 1)
            )
    }

    private func resolvedErrorMessage(_ rawValue: String) -> String {
        if rawValue == "apple_sign_in_unavailable" {
            return text("apple_sign_in_unavailable")
        }

        return rawValue
    }

    private func text(_ key: String) -> String {
        key.localized(with: localizationManager)
    }
}

#Preview("Apple 登录页") {
    PreviewContainer(authManager: PreviewSupport.makeSignedOutAuthManager()) {
        SignInView()
    }
}
