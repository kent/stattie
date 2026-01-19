import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class ShareViewModel {
    var isGeneratingImage = false
    var shareImage: UIImage?

    func generateShareImage(from view: some View, size: CGSize) {
        isGeneratingImage = true

        let renderer = ImageRenderer(content: view.frame(width: size.width))
        renderer.scale = UIScreen.main.scale

        shareImage = renderer.uiImage
        isGeneratingImage = false
    }

    func shareItems(for game: Game) -> [Any] {
        var items: [Any] = []

        let text = ShareService.shared.generateTextSummary(for: game)
        items.append(text)

        if let image = shareImage {
            items.append(image)
        }

        return items
    }
}
