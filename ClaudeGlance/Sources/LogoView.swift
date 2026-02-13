import SwiftUI

struct LogoView: View {
    let isActive: Bool

    var body: some View {
        if let nsImage = NSImage(contentsOf: imageURL) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }

    private var imageURL: URL {
        let name = isActive ? "logo-orange" : "logo-grey"
        return Bundle.module.url(forResource: name, withExtension: "png")!
    }
}
