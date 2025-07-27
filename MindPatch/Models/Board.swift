import Foundation
import SwiftUI

struct Board: Identifiable, Hashable {
    let block: Block

    var id: UUID { block.id }
    var title: String { block.content }

    var iconUrl: String? {
        block.props?["iconUrl"]?.value as? String
    }

    var iconImage: Image {
        if let iconUrl = iconUrl {
            if let uiImage = UIImage(named: iconUrl) {
                return Image(uiImage: uiImage)
            }
        }
        return Image(systemName: "folder")
    }
}
