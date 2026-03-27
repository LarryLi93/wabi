import SwiftUI
import SwiftData

@MainActor
enum PreviewSupport {
    static var sampleNotes: [Note] {
        [
            Note(
                title: "晨间阅读摘记",
                content: "把今天读到的句子整理成一张卡片，下午再回看一次。",
                category: "阅读",
                referenceURL: Note.serializedReferenceURLs(from: [
                    "https://example.com/article-1",
                    "https://example.com/article-2"
                ]),
                createTime: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                lastReviewedAt: Calendar.current.date(byAdding: .day, value: -4, to: Date()),
                reviewCount: 2
            ),
            Note(
                title: "写作结构草稿",
                content: "先把段落顺序定下来，再决定语气和节奏。",
                category: "写作",
                referenceURL: "writer.example.com",
                createTime: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                lastReviewedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                reviewCount: 1
            ),
            Note(
                title: "研究线索",
                content: "这一主题还缺少案例，需要补两篇论文作为对照。",
                category: "研究",
                createTime: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date(),
                reviewCount: 0
            )
        ]
    }

    static func makeContainer(notes: [Note]? = nil) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Note.self, configurations: configuration)

        (notes ?? sampleNotes).forEach { container.mainContext.insert($0) }
        return container
    }

    static func makeLocalizationManager(language: String = "zh") -> LocalizationManager {
        let manager = LocalizationManager()
        manager.setLanguage(language)
        return manager
    }

    static func makeSignedInAuthManager() -> AuthSessionManager {
        let manager = AuthSessionManager(shouldRestoreSession: false)
        manager.applyPreviewUser(
            AuthUserProfile(
                userIdentifier: "preview-user",
                fullName: "Wabi Reader",
                email: "preview@wabi.app"
            )
        )
        return manager
    }

    static func makeSignedOutAuthManager() -> AuthSessionManager {
        let manager = AuthSessionManager(shouldRestoreSession: false)
        manager.applyPreviewUser(nil)
        return manager
    }
}

@MainActor
struct PreviewContainer<Content: View>: View {
    let language: String
    let notes: [Note]
    let authManager: AuthSessionManager
    let content: Content

    init(
        language: String = "zh",
        notes: [Note]? = nil,
        authManager: AuthSessionManager? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.language = language
        self.notes = notes ?? PreviewSupport.sampleNotes
        self.authManager = authManager ?? PreviewSupport.makeSignedInAuthManager()
        self.content = content()
    }

    var body: some View {
        content
            .environmentObject(authManager)
            .environmentObject(PreviewSupport.makeLocalizationManager(language: language))
            .modelContainer(PreviewSupport.makeContainer(notes: notes))
    }
}
