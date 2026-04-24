import SwiftUI
import SwiftData

struct EditNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var localizationManager: LocalizationManager
    @Query(sort: \Note.createTime, order: .reverse) private var existingNotes: [Note]

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var selectedCategoryOption: String = CategoryOption.none.rawValue
    @State private var customCategory: String = ""
    @State private var referenceLinks: [ReferenceLinkField] = [ReferenceLinkField()]

    @State private var hasLoadedNote = false
    @FocusState private var focusedField: EditorField?

    private let note: Note?

    init(note: Note? = nil) {
        self.note = note
    }

    var body: some View {
        ZStack {
            WabiTheme.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(text(note == nil ? "editor_new_title" : "editor_edit_title"))
                            .font(.system(size: 30, weight: .semibold, design: .serif))
                            .foregroundStyle(WabiTheme.textPrimary)

                        Text(text(note == nil ? "editor_new_subtitle" : "editor_edit_subtitle"))
                            .font(.system(size: 15))
                            .foregroundStyle(WabiTheme.textSecondary)
                    }

                    EditorFieldCard(title: text("title")) {
                        TextField(text("note_title_placeholder"), text: $title, axis: .vertical)
                            .font(.system(size: 18, weight: .medium, design: .serif))
                            .foregroundStyle(WabiTheme.textPrimary)
                            .textInputAutocapitalization(.sentences)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .title)
                            .onSubmit {
                                focusedField = selectedCategoryOption == CategoryOption.new.rawValue ? .newCategory : .body
                            }
                            .padding(16)
                            .background(fieldBackground)
                    }

                    EditorFieldCard(title: text("category")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("", selection: $selectedCategoryOption) {
                                Text(text("category_none_option"))
                                    .tag(CategoryOption.none.rawValue)

                                ForEach(availableCategories, id: \.self) { category in
                                    Text(category)
                                        .tag(category)
                                }

                                Text(text("category_new_option"))
                                    .tag(CategoryOption.new.rawValue)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(fieldBackground)

                            if selectedCategoryOption == CategoryOption.new.rawValue {
                                TextField(text("new_category_placeholder"), text: $customCategory)
                                    .font(.system(size: 16))
                                    .foregroundStyle(WabiTheme.textPrimary)
                                    .focused($focusedField, equals: .newCategory)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .body
                                    }
                                    .padding(16)
                                    .background(fieldBackground)
                            }
                        }
                    }

                    EditorFieldCard(title: text("card_body")) {
                        VStack(alignment: .leading, spacing: 14) {
                            ZStack(alignment: .topLeading) {
                                if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(text("card_body_placeholder"))
                                        .font(.system(size: 16))
                                        .foregroundStyle(WabiTheme.textMuted)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 20)
                                }

                                TextEditor(text: $bodyText)
                                    .font(.system(size: 16))
                                    .foregroundStyle(WabiTheme.textPrimary)
                                    .frame(minHeight: 280)
                                    .scrollContentBackground(.hidden)
                                    .padding(12)
                                    .focused($focusedField, equals: .body)
                                    .background(fieldBackground)
                            }

                            Text(text("body_helper"))
                                .font(.system(size: 13))
                                .foregroundStyle(WabiTheme.textMuted)
                        }
                    }

                    EditorFieldCard(title: text("reference_link")) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach($referenceLinks) { $link in
                                HStack(spacing: 10) {
                                    TextField(text("reference_link_placeholder"), text: $link.value)
                                        .font(.system(size: 16))
                                        .foregroundStyle(WabiTheme.textPrimary)
                                        .textInputAutocapitalization(.never)
                                        .keyboardType(.URL)
                                        .autocorrectionDisabled()
                                        .padding(16)
                                        .background(fieldBackground)

                                    if referenceLinks.count > 1 {
                                        Button {
                                            removeLinkField(id: link.id)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundStyle(WabiTheme.textMuted)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            Button {
                                referenceLinks.append(ReferenceLinkField())
                            } label: {
                                Label(text("add_reference_link"), systemImage: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(WabiTheme.accent)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(WabiTheme.accentSoft.opacity(0.24))
                                    )
                            }
                            .buttonStyle(.plain)

                            Text(text("reference_links_helper"))
                                .font(.system(size: 13))
                                .foregroundStyle(WabiTheme.textMuted)
                        }
                    }

                    if let note {
                        EditorFieldCard(title: text("review_memory")) {
                            VStack(alignment: .leading, spacing: 12) {
                                EditorMetaRow(
                                    label: text("created_on"),
                                    value: note.createTime.formatted(
                                        Date.FormatStyle(date: .abbreviated, time: .omitted)
                                            .locale(currentLocale)
                                    )
                                )
                                EditorMetaRow(label: text("last_reviewed"), value: reviewStatus(for: note))
                                EditorMetaRow(label: text("review_times"), value: "\(note.reviewCount)")
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(text(note == nil ? "new_note" : "edit_note"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(text("save")) {
                    saveNote()
                    dismiss()
                }
                .disabled(isSaveDisabled)
                .foregroundStyle(isSaveDisabled ? WabiTheme.textMuted : WabiTheme.accent)
            }
        }
        .onAppear {
            guard !hasLoadedNote else {
                return
            }

            title = note?.title ?? ""
            bodyText = note?.content ?? ""
            if let noteCategory = note?.normalizedCategory {
                if availableCategories.contains(noteCategory) {
                    selectedCategoryOption = noteCategory
                } else {
                    selectedCategoryOption = CategoryOption.new.rawValue
                    customCategory = noteCategory
                }
            } else {
                selectedCategoryOption = CategoryOption.none.rawValue
            }

            let storedLinks = note?.normalizedReferenceURLs ?? []
            referenceLinks = storedLinks.isEmpty
                ? [ReferenceLinkField()]
                : storedLinks.map { ReferenceLinkField(value: $0) }
            hasLoadedNote = true
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(WabiTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(WabiTheme.border.opacity(0.55), lineWidth: 1)
            )
    }

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var availableCategories: [String] {
        Array(Set(existingNotes.compactMap(\.normalizedCategory)))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var selectedCategory: String? {
        switch selectedCategoryOption {
        case CategoryOption.none.rawValue:
            return nil
        case CategoryOption.new.rawValue:
            let value = customCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        default:
            return selectedCategoryOption
        }
    }

    private var normalizedReferenceLinks: [String] {
        referenceLinks
            .map(\.value)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func saveNote() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let serializedReferenceURLs = Note.serializedReferenceURLs(from: normalizedReferenceLinks)

        if let existingNote = note {
            existingNote.title = cleanTitle
            existingNote.category = selectedCategory
            existingNote.content = cleanBody
            existingNote.referenceURL = serializedReferenceURLs
        } else {
            let newNote = Note(
                title: cleanTitle,
                content: cleanBody,
                category: selectedCategory,
                referenceURL: serializedReferenceURLs
            )
            modelContext.insert(newNote)
        }
    }

    private func reviewStatus(for note: Note) -> String {
        guard let lastReviewedAt = note.lastReviewedAt else {
            return text("review_never")
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

    private func removeLinkField(id: UUID) {
        referenceLinks.removeAll { $0.id == id }

        if referenceLinks.isEmpty {
            referenceLinks = [ReferenceLinkField()]
        }
    }
}

private enum EditorField {
    case title
    case newCategory
    case body
}

private enum CategoryOption: String {
    case none = "__none__"
    case new = "__new__"
}

private struct ReferenceLinkField: Identifiable {
    let id: UUID
    var value: String

    init(id: UUID = UUID(), value: String = "") {
        self.id = id
        self.value = value
    }
}

private struct EditorFieldCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WabiTheme.textSecondary)

            content
        }
        .padding(18)
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

private struct EditorMetaRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(WabiTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WabiTheme.textPrimary)
        }
    }
}

#Preview("新建卡片") {
    PreviewContainer {
        EditNoteView()
    }
}

#Preview("编辑卡片") {
    PreviewContainer {
        EditNoteView(note: PreviewSupport.sampleNotes[0])
    }
}
