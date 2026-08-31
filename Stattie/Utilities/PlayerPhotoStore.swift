import Foundation
import SwiftData
import UIKit

/// Compresses player photos so CloudKit export can store them as CKAssets
/// instead of overflowing the 1 MB CKRecord limit with original camera images.
enum PlayerPhotoStore {
    static let maxPixelSize: CGFloat = 512
    static let maxByteCount = 400_000
    static let minimumJPEGQuality: CGFloat = 0.32
    private static let initialJPEGQuality: CGFloat = 0.72

    static func preparedData(from original: Data?) -> Data? {
        guard let original, !original.isEmpty else { return nil }

        guard let image = UIImage(data: original) else {
            return original.count > maxByteCount ? nil : original
        }

        let largestSide = max(image.size.width, image.size.height)
        if original.count <= maxByteCount, largestSide <= maxPixelSize {
            return original
        }

        let resized = resizedImage(image)
        var quality = initialJPEGQuality
        var compressed = resized.jpegData(compressionQuality: quality)

        while let current = compressed,
              current.count > maxByteCount,
              quality > minimumJPEGQuality {
            quality -= 0.1
            compressed = resized.jpegData(compressionQuality: quality)
        }

        if let compressed {
            if compressed.count < original.count {
                return compressed
            }
            if original.count <= maxByteCount {
                return original
            }
            return compressed
        }

        return original.count > maxByteCount ? nil : original
    }

    @discardableResult
    static func migrateOversizedPhotos(in context: ModelContext) throws -> Int {
        let people = try context.fetch(FetchDescriptor<Person>())
        var rewritten = 0

        for person in people {
            guard let existing = person.photoData, !existing.isEmpty else { continue }
            let prepared = preparedData(from: existing)
            if prepared != existing {
                person.photoData = prepared
                rewritten += 1
            }
        }

        if context.hasChanges {
            try context.save()
        }

        return rewritten
    }

    private static func resizedImage(_ image: UIImage) -> UIImage {
        let largestSide = max(image.size.width, image.size.height)
        guard largestSide > maxPixelSize, largestSide > 0 else { return image }

        let scale = maxPixelSize / largestSide
        let newSize = CGSize(
            width: max(1, (image.size.width * scale).rounded()),
            height: max(1, (image.size.height * scale).rounded())
        )
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
