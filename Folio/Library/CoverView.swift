import SwiftUI

/// A book cover at 2:3. Books without cover art get a cloth-bound cover set in type.
struct CoverView: View {
    let book: BookRecord
    let image: UIImage?

    var body: some View {
        Color.clear
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    GeneratedCover(title: book.title, author: book.author)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(alignment: .leading) {
                // The sheen of a spine hinge.
                LinearGradient(
                    colors: [.white.opacity(0.22), .black.opacity(0.12), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 9)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
            .shadow(color: .black.opacity(0.16), radius: 14, y: 8)
    }
}

private struct GeneratedCover: View {
    let title: String
    let author: String

    private static let palettes: [(UInt32, UInt32)] = [
        (0x7A2E25, 0x4A1A15), // oxblood
        (0x2E4A3B, 0x1A2D23), // forest
        (0x27394F, 0x162231), // navy
        (0x86682F, 0x56421C), // ochre
        (0x58344F, 0x371E31), // plum
        (0x45505A, 0x2A3238), // slate
    ]

    var body: some View {
        let palette = Self.palettes[Self.stableHash(title) % Self.palettes.count]
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack {
                LinearGradient(
                    colors: [Color(UIColor(hex: palette.0)), Color(UIColor(hex: palette.1))],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: width * 0.06) {
                    Spacer(minLength: 0)
                    Text(title)
                        .font(.system(size: max(width * 0.115, 9), weight: .regular, design: .serif))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .minimumScaleFactor(0.6)
                    Rectangle()
                        .fill(Color(UIColor(hex: 0xC9A86A)))
                        .frame(width: width * 0.22, height: max(width * 0.006, 0.5))
                    Text(author)
                        .font(.system(size: max(width * 0.065, 7), design: .serif).smallCaps())
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .opacity(0.85)
                    Spacer(minLength: 0)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Color(UIColor(hex: 0xF3EBDD)))
                .padding(.horizontal, width * 0.12)
            }
        }
    }

    /// Swift's `hashValue` changes between launches, so covers would change colour without this.
    private static func stableHash(_ string: String) -> Int {
        var hash: UInt64 = 5381
        for scalar in string.unicodeScalars {
            hash = (hash &* 33) &+ UInt64(scalar.value)
        }
        return Int(hash % 1_000_003)
    }
}
