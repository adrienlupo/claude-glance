import SwiftUI

struct LogoView: View {
    let isActive: Bool

    private static let activeImage = loadImage(named: "logo-orange")
    private static let inactiveImage = loadImage(named: "logo-grey")

    var body: some View {
        if let nsImage = isActive ? Self.activeImage : Self.inactiveImage {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }

    private static func loadImage(named name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
