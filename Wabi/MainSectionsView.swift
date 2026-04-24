import SwiftUI

private enum NoteFilter: Hashable {
    case all
    case reviewDue
    case linked
    case uncategorized
    case category(String)
}

struct HomeSectionView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager

    let notes: [Note]
    let reviewQueue: [Note]
    let categoryNames: [String]
    let linkedCount: Int
    let categorizedCount: Int
    let onEdit: (Note) -> Void
    let onDelete: (Note) -> Void
    let onReview: (Note) -> Void

    @State private var selectedFilter: NoteFilter = .all
    @State private var searchText: String = ""
    @State private var showNewNote = false
    @State private var editingNote: Note?

    private var availableFilters: [NoteFilter] {
        var filters: [NoteFilter] = [.all]

        if !reviewQueue.isEmpty {
            filters.append(.reviewDue)
        }

        if linkedCount > 0 {
            filters.append(.linked)
        }

        if notes.contains(where: { $0.normalizedCategory == nil }) {
            filters.append(.uncategorized)
        }

        filters.append(contentsOf: categoryNames.map(NoteFilter.category))
        return filters
    }

    private var filteredNotes: [Note] {
        notes.filter(matchesSearch).filter(matchesFilter)
    }

    private var recentNotes: [Note] {
        Array(notes.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    WabiTheme.background
                        .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            Color.clear
                                .frame(height: 1)
                                .id("homeTop")

                            Text(text("home_title"))
                                .font(.system(size: 32, weight: .semibold, design: .serif))
                                .foregroundStyle(WabiTheme.textPrimary)
                                .padding(.top, 8)

                            searchSection
                            filtersSection

                            if notes.isEmpty {
                                EmptyCollectionCard(
                                    title: text("no_notes"),
                                    description: text("empty_description"),
                                    actionTitle: text("start_writing"),
                                    action: { showNewNote = true }
                                )
                            } else {
                                Text(resultsSummary)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(WabiTheme.textMuted)

                                librarySection
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 140)
                    }
                    
                    VStack(spacing: 12) {
                        FloatingActionButton(systemImage: "arrow.up") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo("homeTop", anchor: .top)
                            }
                        }

                        FloatingActionButton(systemImage: "plus", fillsAccent: true, action: { showNewNote = true })
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 18)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showNewNote) {
                EditNoteView()
            }
            .navigationDestination(item: $editingNote) { note in
                EditNoteView(note: note)
            }
        }
        .onChange(of: availableFilters) { _, newFilters in
            if !newFilters.contains(selectedFilter) {
                selectedFilter = .all
            }
        }
    }

    private var searchSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(WabiTheme.textMuted)

            TextField(text("search_placeholder"), text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .foregroundStyle(WabiTheme.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(WabiTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(fieldBackground)
    }

    private var filtersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(availableFilters, id: \.self) { filter in
                    FilterChip(title: title(for: filter), isSelected: selectedFilter == filter) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
        }
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if filteredNotes.isEmpty {
                EmptyCollectionCard(
                    title: text("no_results_title"),
                    description: text("no_results_description"),
                    actionTitle: text("clear_filter"),
                    action: {
                        selectedFilter = .all
                        searchText = ""
                    }
                )
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(filteredNotes) { note in
                        NoteCard(note: note, onEdit: {
                            editingNote = note
                        }, onReview: {
                            onReview(note)
                        }, onDelete: {
                            onDelete(note)
                        })
                    }
                }
            }
        }
    }

    private func title(for filter: NoteFilter) -> String {
        switch filter {
        case .all:
            return text("filter_all")
        case .reviewDue:
            return text("filter_review")
        case .linked:
            return text("filter_linked")
        case .uncategorized:
            return text("filter_uncategorized")
        case let .category(name):
            return name
        }
    }

    private func matchesFilter(_ note: Note) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .reviewDue:
            return note.isReviewDue
        case .linked:
            return note.resolvedReferenceURL != nil
        case .uncategorized:
            return note.normalizedCategory == nil
        case let .category(name):
            return note.normalizedCategory == name
        }
    }

    private func matchesSearch(_ note: Note) -> Bool {
        let rawQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawQuery.isEmpty else {
            return true
        }

        let searchableText = [
            note.title,
            note.content,
            note.normalizedCategory ?? "",
            note.normalizedReferenceURLs.joined(separator: "\n")
        ].joined(separator: "\n")

        let queryTerms = rawQuery
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        return queryTerms.allSatisfy { searchableText.localizedCaseInsensitiveContains($0) }
    }

    private var resultsSummary: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(format: text("search_results_summary"), locale: currentLocale, filteredNotes.count)
        }

        if selectedFilter != .all {
            return String(format: text("filter_results_summary"), locale: currentLocale, filteredNotes.count)
        }

        return String(format: text("all_results_summary"), locale: currentLocale, filteredNotes.count)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(WabiTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(WabiTheme.border.opacity(0.45), lineWidth: 1)
            )
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(WabiTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(WabiTheme.border.opacity(0.55), lineWidth: 1)
            )
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(WabiTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(WabiTheme.textSecondary)
        }
    }

    private func text(_ key: String) -> String {
        key.localized(with: localizationManager)
    }

    private var currentLocale: Locale {
        localizationManager.locale
    }
}

struct GraphSectionView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager

    let notes: [Note]
    let categoryNames: [String]
    let linkedCount: Int
    let onEdit: (Note) -> Void

    @State private var showNewNote = false
    @State private var editingNote: Note?

    private var groupedNotes: [(name: String, notes: [Note])] {
        let groups = Dictionary(grouping: notes) { note in
            note.normalizedCategory ?? text("uncategorized")
        }

        return groups
            .map { key, value in
                (
                    name: key,
                    notes: value.sorted { $0.createTime > $1.createTime }
                )
            }
            .sorted { left, right in
                if left.notes.count != right.notes.count {
                    return left.notes.count > right.notes.count
                }
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }
    }

    private var linkedNotes: [Note] {
        notes
            .filter { !$0.resolvedReferenceURLs.isEmpty }
            .sorted { $0.createTime > $1.createTime }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WabiTheme.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(text("graph_title"))
                                .font(.system(size: 34, weight: .semibold, design: .serif))
                                .foregroundStyle(WabiTheme.textPrimary)

                            Text(text("graph_subtitle"))
                                .font(.system(size: 15))
                                .foregroundStyle(WabiTheme.textSecondary)
                        }

                        if notes.isEmpty {
                            EmptyCollectionCard(
                                title: text("graph_empty_title"),
                                description: text("graph_empty_description"),
                                actionTitle: text("start_writing"),
                                action: { showNewNote = true }
                            )
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    StatCard(title: text("stats_total"), value: "\(notes.count)", icon: "square.stack.3d.up")
                                    StatCard(title: text("graph_categories_count"), value: "\(categoryNames.count)", icon: "square.grid.2x2")
                                    StatCard(title: text("stats_linked"), value: "\(linkedCount)", icon: "link")
                                }
                                .padding(.vertical, 2)
                            }

                            VStack(alignment: .leading, spacing: 14) {
                                sectionTitle(text("graph_categories_title"), subtitle: text("graph_categories_subtitle"))

                                LazyVStack(spacing: 14) {
                                    ForEach(groupedNotes, id: \.name) { group in
                                        GraphClusterCard(
                                            title: group.name,
                                            countText: String(format: text("graph_cluster_count"), locale: currentLocale, group.notes.count),
                                            notes: Array(group.notes.prefix(3)),
                                            onEdit: { editingNote = $0 }
                                        )
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 14) {
                                sectionTitle(text("graph_links_title"), subtitle: text("graph_links_subtitle"))

                                if linkedNotes.isEmpty {
                                    EmptyCollectionCard(
                                        title: text("graph_links_empty_title"),
                                        description: text("graph_links_empty_description"),
                                        actionTitle: text("open_card"),
                                        action: {
                                            if let note = notes.first {
                                                editingNote = note
                                            }
                                        }
                                    )
                                } else {
                                    LazyVStack(spacing: 12) {
                                        ForEach(linkedNotes) { note in
                                            LinkTrailCard(note: note, onEdit: {
                                                editingNote = note
                                            })
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showNewNote) {
                EditNoteView()
            }
            .navigationDestination(item: $editingNote) { note in
                EditNoteView(note: note)
            }
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(WabiTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(WabiTheme.textSecondary)
        }
    }

    private func text(_ key: String) -> String {
        key.localized(with: localizationManager)
    }

    private var currentLocale: Locale {
        localizationManager.locale
    }
}

struct ReviewSectionView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager

    let notes: [Note]
    let reviewQueue: [Note]
    let onEdit: (Note) -> Void
    let onDelete: (Note) -> Void
    let onReview: (Note) -> Void

    @State private var showNewNote = false
    @State private var editingNote: Note?

    private var recentlyReviewed: [Note] {
        notes
            .filter { $0.lastReviewedAt != nil }
            .sorted { ($0.lastReviewedAt ?? .distantPast) > ($1.lastReviewedAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WabiTheme.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(text("review_page_title"))
                                .font(.system(size: 34, weight: .semibold, design: .serif))
                                .foregroundStyle(WabiTheme.textPrimary)

                            Text(text("review_page_subtitle"))
                                .font(.system(size: 15))
                                .foregroundStyle(WabiTheme.textSecondary)
                        }

                        if notes.isEmpty {
                            EmptyCollectionCard(
                                title: text("review_empty_title"),
                                description: text("review_empty_description"),
                                actionTitle: text("start_writing"),
                                action: { showNewNote = true }
                            )
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    StatCard(title: text("stats_due"), value: "\(reviewQueue.count)", icon: "clock")
                                    StatCard(title: text("review_finished_count"), value: "\(recentlyReviewed.count)", icon: "checkmark.circle")
                                    StatCard(title: text("review_total_count"), value: "\(notes.reduce(0) { $0 + $1.reviewCount })", icon: "sparkles")
                                }
                                .padding(.vertical, 2)
                            }

                            VStack(alignment: .leading, spacing: 14) {
                                sectionTitle(text("review_due_title"), subtitle: text("review_due_subtitle"))

                                if reviewQueue.isEmpty {
                                    EmptyCollectionCard(
                                        title: text("review_clear_title"),
                                        description: text("review_clear_description"),
                                        actionTitle: text("tab_home"),
                                        action: { }
                                    )
                                } else {
                                    LazyVStack(spacing: 14) {
                                        ForEach(reviewQueue) { note in
                                            ReviewDeckCard(note: note, onEdit: {
                                                editingNote = note
                                            }, onReview: {
                                                onReview(note)
                                            }, onDelete: {
                                                onDelete(note)
                                            })
                                        }
                                    }
                                }
                            }

                            if !recentlyReviewed.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    sectionTitle(text("recent_reviewed_title"), subtitle: text("recent_reviewed_subtitle"))

                                    LazyVStack(spacing: 12) {
                                        ForEach(Array(recentlyReviewed.prefix(6))) { note in
                                            ReviewedHistoryCard(note: note, onEdit: {
                                                editingNote = note
                                            })
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showNewNote) {
                EditNoteView()
            }
            .navigationDestination(item: $editingNote) { note in
                EditNoteView(note: note)
            }
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(WabiTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(WabiTheme.textSecondary)
        }
    }

    private func text(_ key: String) -> String {
        key.localized(with: localizationManager)
    }
}

struct SettingsSectionView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var authManager: AuthSessionManager

    let onShowLanguagePicker: () -> Void
    let onOpenAccount: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                WabiTheme.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(text("settings_title"))
                            .font(.system(size: 34, weight: .semibold, design: .serif))
                            .foregroundStyle(WabiTheme.textPrimary)
                            .padding(.top, 24)

                        // Account Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text(text("settings_account_section"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(WabiTheme.textSecondary)
                                .padding(.horizontal, 4)

                            Button(action: onOpenAccount) {
                                HStack(spacing: 16) {
                                    Text(authManager.currentUser?.initials ?? "?")
                                        .font(.system(size: 20, weight: .semibold, design: .serif))
                                        .foregroundStyle(Color.white)
                                        .frame(width: 52, height: 52)
                                        .background(Circle().fill(WabiTheme.accent))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(authManager.currentUser?.displayName ?? text("account_no_name"))
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(WabiTheme.textPrimary)

                                        Text(authManager.currentUser?.email ?? text("account_no_email"))
                                            .font(.system(size: 13))
                                            .foregroundStyle(WabiTheme.textMuted)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(WabiTheme.textMuted)
                                }
                                .padding(18)
                                .background(cardBackground)
                            }
                            .buttonStyle(.plain)
                        }

                        // App Settings Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text(text("settings_app_section"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(WabiTheme.textSecondary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                Button(action: onShowLanguagePicker) {
                                    HStack {
                                        Label(text("settings_language"), systemImage: "globe")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(WabiTheme.textPrimary)

                                        Spacer()

                                        Text(localizationManager.currentLanguage == "en" ? "English" : "中文")
                                            .font(.system(size: 14))
                                            .foregroundStyle(WabiTheme.textSecondary)

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(WabiTheme.textMuted)
                                    }
                                    .padding(18)
                                }
                                .buttonStyle(.plain)
                            }
                            .background(cardBackground)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(WabiTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(WabiTheme.border.opacity(0.45), lineWidth: 1)
            )
    }

    private func text(_ key: String) -> String {
        key.localized(with: localizationManager)
    }
}

private struct FloatingActionButton: View {
    let systemImage: String
    var fillsAccent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(fillsAccent ? Color.white : WabiTheme.textSecondary)
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(fillsAccent ? WabiTheme.accent : WabiTheme.surface)
                        .overlay(
                            Circle()
                                .stroke(WabiTheme.border.opacity(fillsAccent ? 0 : 0.55), lineWidth: 1)
                        )
                        .shadow(color: WabiTheme.textPrimary.opacity(0.08), radius: 12, x: 0, y: 6)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyCollectionCard: View {
    let title: String
    let description: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(WabiTheme.textPrimary)

            Text(description)
                .font(.system(size: 15))
                .foregroundStyle(WabiTheme.textSecondary)

            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        Capsule()
                            .fill(WabiTheme.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(WabiTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(WabiTheme.border.opacity(0.45), lineWidth: 1)
                )
        )
    }
}

struct NoteCard: View {
    @EnvironmentObject private var localizationManager: LocalizationManager

    let note: Note
    let onEdit: () -> Void
    let onReview: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(note.title)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(WabiTheme.textPrimary)
                    .lineLimit(1)

                Text(note.content.isEmpty ? text("empty_note_content") : note.content)
                    .font(.system(size: 14))
                    .foregroundStyle(WabiTheme.textSecondary)
                    .lineSpacing(2)
                    .lineLimit(2)
            }

            HStack(alignment: .bottom) {
                if let category = note.normalizedCategory {
                    Text("#\(category)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(WabiTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(WabiTheme.accentSoft.opacity(0.3))
                        )
                }

                Spacer()

                Text(createdDateText)
                    .font(.system(size: 12))
                    .foregroundStyle(WabiTheme.textMuted)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: onEdit)
        .contextMenu {
            Button(action: onEdit) {
                Label(text("open_card"), systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label(text("delete"), systemImage: "trash")
            }
        }
    }

    private var createdDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: note.createTime)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(WabiTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(WabiTheme.border.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: WabiTheme.textPrimary.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private func text(_ key: String) -> String {
        key.localized(with: localizationManager)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(WabiTheme.accent)

            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(WabiTheme.textPrimary)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WabiTheme.textSecondary)
        }
        .frame(width: 148, alignment: .leading)
        .frame(minHeight: 120, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(WabiTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(WabiTheme.border.opacity(0.45), lineWidth: 1)
                )
        )
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : WabiTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? WabiTheme.accent : WabiTheme.surface)
                        .overlay(
                            Capsule()
                                .stroke(WabiTheme.border.opacity(isSelected ? 0 : 0.55), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct NoteActionsMenu: View {
    let openLinkTitle: String
    let editTitle: String
    let deleteTitle: String
    let url: URL?
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Menu {
            Button(editTitle, action: onEdit)

            if let url {
                Link(openLinkTitle, destination: url)
            }

            Button(deleteTitle, role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WabiTheme.textSecondary)
                .frame(width: 30, height: 30)
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

struct ReviewDeckCard: View {
    @EnvironmentObject private var localizationManager: LocalizationManager

    let note: Note
    let onEdit: () -> Void
    let onReview: () -> Void
    let onDelete: () -> Void

    private var primaryReferenceURL: URL? {
        note.resolvedReferenceURLs.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Text(note.normalizedCategory ?? text("uncategorized"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WabiTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(WabiTheme.accentSoft.opacity(0.34))
                        )

                    NoteActionsMenu(
                        openLinkTitle: text("open_link"),
                        editTitle: text("open_card"),
                        deleteTitle: text("delete"),
                        url: primaryReferenceURL,
                        onEdit: onEdit,
                        onDelete: onDelete
                    )
                }

                Spacer()
            }

            Text(note.title)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(WabiTheme.textPrimary)
                .lineLimit(2)

            Text(note.content.isEmpty ? text("empty_note_content") : note.content)
                .font(.system(size: 14))
                .foregroundStyle(WabiTheme.textSecondary)
                .lineSpacing(3)
                .lineLimit(5)

            Text(reviewStatus)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WabiTheme.textMuted)

            HStack(spacing: 10) {
                Button(action: onReview) {
                    Text(text("review_action"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(WabiTheme.accent)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onEdit) {
                    Text(text("open_card"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(WabiTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(WabiTheme.surface)
                                .overlay(
                                    Capsule()
                                        .stroke(WabiTheme.border.opacity(0.55), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(WabiTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(WabiTheme.border.opacity(0.45), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture(perform: onEdit)
    }

    private var reviewStatus: String {
        guard let lastReviewedAt = note.lastReviewedAt else {
            return text("review_queue_new")
        }

        let days = Calendar.current.dateComponents([.day], from: lastReviewedAt, to: Date()).day ?? 0
        if days == 0 {
            return text("review_today")
        }

        return String(format: text("review_days_ago"), locale: currentLocale, days)
    }

    private func text(_ key: String) -> String {
        key.localized(with: localizationManager)
    }

    private var currentLocale: Locale {
        localizationManager.locale
    }
}

private struct GraphClusterCard: View {
    @EnvironmentObject private var localizationManager: LocalizationManager

    let title: String
    let countText: String
    let notes: [Note]
    let onEdit: (Note) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(WabiTheme.textPrimary)

                    Text(countText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(WabiTheme.textMuted)
                }

                Spacer()
            }

            ForEach(notes) { note in
                Button {
                    onEdit(note)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(WabiTheme.accentSoft)
                            .frame(width: 8, height: 8)
                            .padding(.top, 7)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(WabiTheme.textPrimary)
                                .multilineTextAlignment(.leading)

                            Text(note.content.isEmpty ? text("empty_note_content") : note.content)
                                .font(.system(size: 13))
                                .foregroundStyle(WabiTheme.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(WabiTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(WabiTheme.border.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private func text(_ key: String) -> String {
        key.localized(with: localizationManager)
    }
}

private struct LinkTrailCard: View {
    @EnvironmentObject private var localizationManager: LocalizationManager

    let note: Note
    let onEdit: () -> Void

    private var primaryReferenceURL: URL? {
        note.resolvedReferenceURLs.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(note.title)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(WabiTheme.textPrimary)

                Spacer()

                if let url = primaryReferenceURL {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(WabiTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(note.normalizedReferenceURLs.prefix(3)), id: \.self) { link in
                    Text(link)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(WabiTheme.textMuted)
                        .lineLimit(1)
                }

                if note.normalizedReferenceURLs.count > 3 {
                    Text(String(format: text("more_links_count"), locale: currentLocale, note.normalizedReferenceURLs.count - 3))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(WabiTheme.textMuted)
                }
            }

            Button(text("open_card"), action: onEdit)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WabiTheme.accent)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(WabiTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(WabiTheme.border.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private func text(_ key: String) -> String {
        key.localized(with: localizationManager)
    }

    private var currentLocale: Locale {
        localizationManager.locale
    }
}

private struct ReviewedHistoryCard: View {
    @EnvironmentObject private var localizationManager: LocalizationManager

    let note: Note
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(note.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(WabiTheme.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(historyText)
                        .font(.system(size: 13))
                        .foregroundStyle(WabiTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WabiTheme.textMuted)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(WabiTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(WabiTheme.border.opacity(0.45), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var historyText: String {
        guard let lastReviewedAt = note.lastReviewedAt else {
            return text("review_never")
        }

        let dateText = lastReviewedAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(currentLocale))
        return "\(dateText) · \(String(format: text("reviewed_count"), locale: currentLocale, note.reviewCount))"
    }

    private func text(_ key: String) -> String {
        key.localized(with: localizationManager)
    }

    private var currentLocale: Locale {
        localizationManager.locale
    }
}

#Preview("首页分区") {
    PreviewContainer {
        HomeSectionView(
            notes: PreviewSupport.sampleNotes,
            reviewQueue: PreviewSupport.sampleNotes.filter(\.isReviewDue),
            categoryNames: Array(Set(PreviewSupport.sampleNotes.compactMap(\.normalizedCategory))).sorted(),
            linkedCount: PreviewSupport.sampleNotes.filter { !$0.resolvedReferenceURLs.isEmpty }.count,
            categorizedCount: PreviewSupport.sampleNotes.filter { $0.normalizedCategory != nil }.count,
            onEdit: { _ in },
            onDelete: { _ in },
            onReview: { _ in }
        )
    }
}

#Preview("图谱分区") {
    PreviewContainer {
        GraphSectionView(
            notes: PreviewSupport.sampleNotes,
            categoryNames: Array(Set(PreviewSupport.sampleNotes.compactMap(\.normalizedCategory))).sorted(),
            linkedCount: PreviewSupport.sampleNotes.filter { !$0.resolvedReferenceURLs.isEmpty }.count,
            onEdit: { _ in }
        )
    }
}

#Preview("回顾分区") {
    PreviewContainer {
        ReviewSectionView(
            notes: PreviewSupport.sampleNotes,
            reviewQueue: PreviewSupport.sampleNotes.filter(\.isReviewDue),
            onEdit: { _ in },
            onDelete: { _ in },
            onReview: { _ in }
        )
    }
}

#Preview("设置分区") {
    PreviewContainer {
        SettingsSectionView(
            onShowLanguagePicker: {},
            onOpenAccount: {}
        )
    }
}
