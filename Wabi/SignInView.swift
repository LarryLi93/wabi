import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var authManager: AuthSessionManager

    var body: some View {
        ZStack {
            // 背景图
            Image("banner")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 140)

                // Logo
                Text("WaBi")
                    .font(.system(size: 48, weight: .light, design: .serif))
                    .foregroundStyle(WabiTheme.textPrimary)

                Spacer()
                    .frame(height: 16)

                // Tagline
                Text(text("sign_in_tagline"))
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(WabiTheme.textSecondary)
                    .tracking(1)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)

                Spacer()

                // Sign in button
                signInButton
                    .padding(.horizontal, 40)

                Spacer()
                    .frame(height: 20)

                // Language toggle
                languageToggle

                Spacer()
                    .frame(height: 60)
            }
        }
        .animation(.easeOut(duration: 0.3), value: authManager.isProcessing)
    }

    private var signInButton: some View {
        ZStack {
            SignInWithAppleButton(.continue) { request in
                withAnimation {
                    authManager.clearError()
                    authManager.startProcessing()
                }
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                withAnimation {
                    authManager.handleAuthorizationResult(result)
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .clipShape(Capsule())
            .opacity(authManager.isProcessing ? 0.0 : 1.0)
            .disabled(authManager.isProcessing)

            if authManager.isProcessing {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(WabiTheme.accent)
                    Text(text("loading"))
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(WabiTheme.textSecondary)
                }
                .frame(height: 52)
                .frame(maxWidth: .infinity)
                .background(WabiTheme.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(WabiTheme.border.opacity(0.5), lineWidth: 0.5)
                )
            }
        }
    }

    private var languageToggle: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut) {
                    localizationManager.setLanguage("en")
                }
            } label: {
                Text("EN")
                    .font(.system(size: 14, weight: localizationManager.currentLanguage == "en" ? .medium : .light))
                    .foregroundStyle(localizationManager.currentLanguage == "en" ? WabiTheme.textPrimary : WabiTheme.textMuted)
            }
            .buttonStyle(.plain)

            Text("/")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(WabiTheme.textMuted)

            Button {
                withAnimation(.easeInOut) {
                    localizationManager.setLanguage("zh")
                }
            } label: {
                Text("ZH")
                    .font(.system(size: 14, weight: localizationManager.currentLanguage == "zh" ? .medium : .light))
                    .foregroundStyle(localizationManager.currentLanguage == "zh" ? WabiTheme.textPrimary : WabiTheme.textMuted)
            }
            .buttonStyle(.plain)
        }
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
