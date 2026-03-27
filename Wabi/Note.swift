import Foundation
import SwiftData

@Model
class Note {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var category: String?
    var referenceURL: String?
    var createTime: Date = Date()
    var lastReviewedAt: Date?
    var reviewCount: Int = 0

    init(
        title: String,
        content: String,
        category: String? = nil,
        referenceURL: String? = nil,
        createTime: Date = Date(),
        lastReviewedAt: Date? = nil,
        reviewCount: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.category = category
        self.referenceURL = referenceURL
        self.createTime = createTime
        self.lastReviewedAt = lastReviewedAt
        self.reviewCount = reviewCount
    }
}

extension Note {
    var normalizedCategory: String? {
        let value = category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    var normalizedReferenceURLs: [String] {
        referenceURL?
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
    }

    var normalizedReferenceURL: String? {
        normalizedReferenceURLs.first
    }

    var resolvedReferenceURLs: [URL] {
        normalizedReferenceURLs.compactMap(Self.resolveURL)
    }

    var resolvedReferenceURL: URL? {
        resolvedReferenceURLs.first
    }

    var isReviewDue: Bool {
        guard let lastReviewedAt else {
            return true
        }

        let daysSinceReview = Calendar.current.dateComponents([.day], from: lastReviewedAt, to: Date()).day ?? 0
        return daysSinceReview >= 3
    }

    static func serializedReferenceURLs(from values: [String]) -> String? {
        let normalizedValues = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !normalizedValues.isEmpty else {
            return nil
        }

        return normalizedValues.joined(separator: "\n")
    }

    private static func resolveURL(_ rawValue: String) -> URL? {
        if let directURL = URL(string: rawValue), directURL.scheme != nil {
            return directURL
        }

        return URL(string: "https://\(rawValue)")
    }
}
