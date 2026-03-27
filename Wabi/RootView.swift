import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authManager: AuthSessionManager

    var body: some View {
        ZStack {
            if authManager.isRestoringSession {
                AuthLoadingView()
                    .transition(.opacity)
            } else if authManager.currentUser != nil {
                ContentView()
                    .transition(.opacity)
            } else {
                SignInView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isRestoringSession)
        .animation(.easeInOut(duration: 0.3), value: authManager.currentUser != nil)
    }
}

private struct AuthLoadingView: View {
    var body: some View {
        ZStack {
            WabiTheme.background
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .tint(WabiTheme.accent)
                    .scaleEffect(1.15)

                Text("Wabi")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(WabiTheme.textPrimary)
            }
        }
    }
}

#Preview("登录路由") {
    PreviewContainer(authManager: PreviewSupport.makeSignedOutAuthManager()) {
        RootView()
    }
}
