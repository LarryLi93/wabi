import SwiftUI
import SwiftData

enum AppSection: Hashable {
    case home
    case graph
    case review
    case settings
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var authManager: AuthSessionManager
    @Query(sort: \Note.createTime, order: .reverse) private var notes: [Note]

    @State private var showLanguagePicker = false
    @State private var pendingDeleteNote: Note?
    @State private var showAccountSheet = false
    @State private var selectedSection: AppSection = .home

    init() {}

    var body: some View {
        ZStack {
            TabView(selection: $selectedSection) {
                HomeSectionView(
                    notes: notes,
                    reviewQueue: reviewQueue,
                    categoryNames: categoryNames,
                    linkedCount: linkedCount,
                    categorizedCount: categorizedCount,
                    onEdit: { _ in },
                    onDelete: { pendingDeleteNote = $0 },
                    onReview: markReviewed
                )
                .tag(AppSection.home)
                .tabItem {
                    Image(systemName: "house")
                    Text(text("tab_home"))
                }

                GraphSectionView(
                    notes: notes,
                    categoryNames: categoryNames,
                    linkedCount: linkedCount,
                    onEdit: { _ in }
                )
                .tag(AppSection.graph)
                .tabItem {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                    Text(text("tab_graph"))
                }

                ReviewSectionView(
                    notes: notes,
                    reviewQueue: reviewQueue,
                    onEdit: { _ in },
                    onDelete: { pendingDeleteNote = $0 },
                    onReview: markReviewed
                )
                .tag(AppSection.review)
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text(text("tab_review"))
                }

                SettingsSectionView(
                    onShowLanguagePicker: { showLanguagePicker = true },
                    onOpenAccount: { showAccountSheet = true }
                )
                .tag(AppSection.settings)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text(text("tab_settings"))
                }
            }

            if showLanguagePicker || pendingDeleteNote != nil || showAccountSheet {
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            if showLanguagePicker {
                LanguagePickerModal(
                    title: text("language_modal_title"),
                    subtitle: text("language_modal_subtitle"),
                    englishSubtitle: text("language_english_subtitle"),
                    chineseSubtitle: text("language_chinese_subtitle"),
                    currentLanguage: localizationManager.currentLanguage,
                    onSelect: { language in
                        localizationManager.setLanguage(language)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            showLanguagePicker = false
                        }
                    },
                    onClose: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            showLanguagePicker = false
                        }
                    }
                )
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }

            if showAccountSheet, let user = authManager.currentUser {
                AccountSheetModal(
                    initials: user.initials,
                    title: user.displayName,
                    subtitle: user.email ?? text("account_no_email"),
                    logoutTitle: text("logout"),
                    closeTitle: text("cancel"),
                    onLogout: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            // Clear auth session first to trigger the view switch immediately
                            authManager.signOut()
                            // Clear all local data associated with the user
                            try? modelContext.delete(model: Note.self)
                        }
                        showAccountSheet = false
                    },
                    onClose: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            showAccountSheet = false
                        }
                    }
                )
                .padding(.horizontal, 20)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                .zIndex(1.5)
            }

            if let note = pendingDeleteNote {
                StyledActionModal(
                    systemImage: "trash",
                    title: text("delete_note_title"),
                    message: String(format: text("delete_note_message"), locale: currentLocale, note.title),
                    primaryTitle: text("delete"),
                    secondaryTitle: text("cancel"),
                    primaryRole: .destructive,
                    onPrimary: {
                        deleteNote(note)
                    },
                    onSecondary: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            pendingDeleteNote = nil
                        }
                    }
                )
                .padding(.horizontal, 20)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .tint(WabiTheme.accent)
    }

    private var categoryNames: [String] {
        Array(Set(notes.compactMap(\.normalizedCategory)))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var reviewQueue: [Note] {
        notes
            .filter(\.isReviewDue)
            .sorted { left, right in
                let leftDate = left.lastReviewedAt ?? .distantPast
                let rightDate = right.lastReviewedAt ?? .distantPast
                if leftDate != rightDate {
                    return leftDate < rightDate
                }
                return left.createTime > right.createTime
            }
    }

    private var linkedCount: Int {
        notes.filter { $0.resolvedReferenceURL != nil }.count
    }

    private var categorizedCount: Int {
        notes.filter { $0.normalizedCategory != nil }.count
    }

    private func markReviewed(_ note: Note) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            note.lastReviewedAt = Date()
            note.reviewCount += 1
        }
    }

    private func deleteNote(_ note: Note) {
        modelContext.delete(note)
        pendingDeleteNote = nil
    }

    private func text(_ key: String) -> String {
        key.localized(with: localizationManager)
    }

    private var currentLocale: Locale {
        localizationManager.locale
    }
}

private struct LanguagePickerModal: View {
    let title: String
    let subtitle: String
    let englishSubtitle: String
    let chineseSubtitle: String
    let currentLanguage: String
    let onSelect: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(WabiTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(WabiTheme.textSecondary)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WabiTheme.textMuted)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(WabiTheme.surface)
                                .overlay(
                                    Circle()
                                        .stroke(WabiTheme.border.opacity(0.5), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 12) {
                LanguageOptionButton(
                    title: "English",
                    subtitle: englishSubtitle,
                    isSelected: currentLanguage == "en",
                    action: { onSelect("en") }
                )

                LanguageOptionButton(
                    title: "中文",
                    subtitle: chineseSubtitle,
                    isSelected: currentLanguage == "zh",
                    action: { onSelect("zh") }
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(WabiTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(WabiTheme.border.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: WabiTheme.textPrimary.opacity(0.1), radius: 24, x: 0, y: 12)
        )
    }
}

private struct LanguageOptionButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(WabiTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(WabiTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? WabiTheme.accent : WabiTheme.textMuted)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? WabiTheme.accentSoft.opacity(0.22) : WabiTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(isSelected ? WabiTheme.accent.opacity(0.35) : WabiTheme.border.opacity(0.45), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct StyledActionModal: View {
    let systemImage: String
    let title: String
    let message: String
    let primaryTitle: String
    let secondaryTitle: String
    let primaryRole: ButtonRole?
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(WabiTheme.accent)
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(WabiTheme.accentSoft.opacity(0.28))
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(WabiTheme.textPrimary)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(WabiTheme.textSecondary)
            }

            HStack(spacing: 12) {
                Button(secondaryTitle, action: onSecondary)
                    .buttonStyle(ModalButtonStyle(kind: .secondary))

                Button(role: primaryRole, action: onPrimary) {
                    Text(primaryTitle)
                }
                .buttonStyle(ModalButtonStyle(kind: .destructive))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(WabiTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(WabiTheme.border.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: WabiTheme.textPrimary.opacity(0.1), radius: 24, x: 0, y: 12)
        )
    }
}

private struct AccountSheetModal: View {
    let initials: String
    let title: String
    let subtitle: String
    let logoutTitle: String
    let closeTitle: String
    let onLogout: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(WabiTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(WabiTheme.textSecondary)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WabiTheme.textMuted)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(WabiTheme.surface)
                                .overlay(
                                    Circle()
                                        .stroke(WabiTheme.border.opacity(0.5), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 16) {
                Text(initials)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.white)
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(WabiTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(WabiTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(WabiTheme.textMuted)
                }

                Spacer()
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(WabiTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(WabiTheme.border.opacity(0.45), lineWidth: 1)
                    )
            )

            HStack(spacing: 12) {
                Button(closeTitle, action: onClose)
                    .buttonStyle(ModalButtonStyle(kind: .secondary))

                Button(role: .destructive, action: onLogout) {
                    Text(logoutTitle)
                }
                .buttonStyle(ModalButtonStyle(kind: .destructive))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(WabiTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(WabiTheme.border.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: WabiTheme.textPrimary.opacity(0.1), radius: 24, x: 0, y: 12)
        )
    }
}

private struct ModalButtonStyle: ButtonStyle {
    enum Kind {
        case secondary
        case destructive
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(kind == .secondary ? WabiTheme.textSecondary : Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(backgroundColor(configuration.isPressed))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(borderColor, lineWidth: kind == .secondary ? 1 : 0)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private func backgroundColor(_ isPressed: Bool) -> Color {
        switch kind {
        case .secondary:
            return isPressed ? WabiTheme.surface.opacity(0.8) : WabiTheme.surface
        case .destructive:
            return isPressed ? Color.red.opacity(0.78) : Color.red.opacity(0.88)
        }
    }

    private var borderColor: Color {
        WabiTheme.border.opacity(0.45)
    }
}

#Preview("应用壳层") {
    PreviewContainer(authManager: PreviewSupport.makeSignedInAuthManager()) {
        ContentView()
    }
}

#Preview("语言切换弹层") {
    ZStack {
        WabiTheme.background
            .ignoresSafeArea()

        Color.black.opacity(0.22)
            .ignoresSafeArea()

        LanguagePickerModal(
            title: "选择语言",
            subtitle: "在这里切换整个应用的阅读语气。",
            englishSubtitle: "使用英文浏览应用",
            chineseSubtitle: "使用中文浏览卡片与导航",
            currentLanguage: "zh",
            onSelect: { _ in },
            onClose: {}
        )
        .padding(.horizontal, 20)
    }
}

#Preview("删除确认弹层") {
    ZStack {
        WabiTheme.background
            .ignoresSafeArea()

        Color.black.opacity(0.22)
            .ignoresSafeArea()

        StyledActionModal(
            systemImage: "trash",
            title: "删除这张卡片？",
            message: "“晨间阅读摘记” 将从卡片馆中移除。",
            primaryTitle: "删除",
            secondaryTitle: "取消",
            primaryRole: .destructive,
            onPrimary: {},
            onSecondary: {}
        )
        .padding(.horizontal, 20)
    }
}
