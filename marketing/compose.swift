// Composes Twitter images from raw iPhone Duo simulator captures: a drawn Duo frame in front of the
// same pages, enlarged and blurred. Run from the repository root:  swift marketing/compose.swift
import AppKit
import SwiftUI

let raw = URL(fileURLWithPath: "marketing/raw")
let output = URL(fileURLWithPath: "marketing/twitter")
let canvas = CGSize(width: 1600, height: 900)
let renderScale: CGFloat = 1.5 // 2400 × 1350 px

func load(_ name: String) -> NSImage {
    guard let image = NSImage(contentsOf: raw.appending(path: "\(name).png")) else {
        fatalError("Missing marketing/raw/\(name).png")
    }
    return image
}

// MARK: - Device parts

/// Graphite edge band, lit from above.
let rimGradient = LinearGradient(
    stops: [
        .init(color: Color(white: 0.62), location: 0),
        .init(color: Color(white: 0.26), location: 0.18),
        .init(color: Color(white: 0.12), location: 0.5),
        .init(color: Color(white: 0.30), location: 0.85),
        .init(color: Color(white: 0.55), location: 1),
    ],
    startPoint: .top,
    endPoint: .bottom
)

struct Button3D: View {
    var length: CGFloat
    var thickness: CGFloat = 4
    var vertical = true

    var body: some View {
        Capsule()
            .fill(LinearGradient(
                colors: [Color(white: 0.55), Color(white: 0.2), Color(white: 0.4)],
                startPoint: vertical ? .leading : .top,
                endPoint: vertical ? .trailing : .bottom
            ))
            .frame(width: vertical ? thickness : length, height: vertical ? length : thickness)
    }
}

/// The Duo open flat: the inner screen inside a thin black border and a graphite rim, with the hinge seam
/// showing at the middle of the top and bottom edges.
struct OpenDuo: View {
    let screen: NSImage
    let width: CGFloat

    var body: some View {
        let height = width * 669 / 951
        let screenRadius = width * 36 / 951
        let bezel = width * 0.017
        let rim = width * 0.0055
        let inner = screenRadius + bezel
        let outer = inner + rim
        let total = CGSize(width: width + 2 * (bezel + rim), height: height + 2 * (bezel + rim))

        ZStack {
            RoundedRectangle(cornerRadius: outer, style: .continuous).fill(rimGradient)
            RoundedRectangle(cornerRadius: inner, style: .continuous)
                .fill(Color.black)
                .padding(rim)
            Image(nsImage: screen)
                .resizable()
                .interpolation(.high)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: screenRadius, style: .continuous))
            // Hinge seam where the two halves meet.
            VStack {
                seam(depth: rim + bezel * 0.6)
                Spacer()
                seam(depth: rim + bezel * 0.6)
            }
            // A faint sheen across the glass.
            RoundedRectangle(cornerRadius: inner, style: .continuous)
                .fill(LinearGradient(
                    colors: [.white.opacity(0.07), .clear, .clear, .white.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .padding(rim)
                .allowsHitTesting(false)
        }
        .frame(width: total.width, height: total.height)
        .background(alignment: .trailing) {
            VStack(spacing: total.height * 0.07) {
                Button3D(length: total.height * 0.13)
                Button3D(length: total.height * 0.08)
            }
            .offset(x: 2.5, y: -total.height * 0.12)
        }
        .background(alignment: .topTrailing) {
            HStack(spacing: total.width * 0.012) {
                Button3D(length: total.width * 0.04, vertical: false)
                Button3D(length: total.width * 0.025, vertical: false)
            }
            .offset(x: -total.width * 0.09, y: -2.5)
        }
    }

    private func seam(depth: CGFloat) -> some View {
        Rectangle()
            .fill(LinearGradient(colors: [Color(white: 0.02), Color(white: 0.18), Color(white: 0.02)], startPoint: .leading, endPoint: .trailing))
            .frame(width: 3, height: depth)
    }
}

/// The Duo closed: the outer screen, with the folded spine along the leading edge.
struct ClosedDuo: View {
    let screen: NSImage
    let width: CGFloat

    var body: some View {
        let height = width * 678 / 466
        let screenRadius = width * 36 / 466
        let bezel = width * 0.034
        let rim = width * 0.011
        let inner = screenRadius + bezel
        let outer = inner + rim
        let spine = width * 0.035
        let total = CGSize(width: width + 2 * (bezel + rim), height: height + 2 * (bezel + rim))

        ZStack {
            RoundedRectangle(cornerRadius: outer, style: .continuous).fill(rimGradient)
            RoundedRectangle(cornerRadius: inner, style: .continuous)
                .fill(Color.black)
                .padding(rim)
            Image(nsImage: screen)
                .resizable()
                .interpolation(.high)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: screenRadius, style: .continuous))
            RoundedRectangle(cornerRadius: inner, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.08), .clear, .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(rim)
        }
        .frame(width: total.width, height: total.height)
        // The rounded spine of the folded hinge.
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: spine, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(white: 0.08), Color(white: 0.45), Color(white: 0.2), Color(white: 0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: spine * 2, height: total.height * 0.96)
                .offset(x: -spine * 0.8)
        }
        .background(alignment: .trailing) {
            VStack(spacing: total.height * 0.05) {
                Button3D(length: total.height * 0.12, thickness: 5)
                Button3D(length: total.height * 0.07, thickness: 5)
            }
            .offset(x: 3, y: -total.height * 0.18)
        }
    }
}

/// The Duo half open in the book posture: each half turns about the hinge toward the viewer.
struct BookDuo: View {
    let screen: NSImage
    let width: CGFloat
    let angle: Double

    var body: some View {
        let device = OpenDuo(screen: screen, width: width)
        let totalWidth = width * (1 + 2 * (0.017 + 0.0055))
        let half = totalWidth / 2
        HStack(spacing: 0) {
            device
                .frame(width: half, alignment: .leading)
                .clipped()
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.18)], startPoint: .leading, endPoint: .trailing))
                .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.55)
            device
                .frame(width: half, alignment: .trailing)
                .clipped()
                .overlay(LinearGradient(colors: [.black.opacity(0.28), .black.opacity(0.06)], startPoint: .leading, endPoint: .trailing))
                .rotation3DEffect(.degrees(-angle), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.55)
        }
    }
}

// MARK: - Scene

/// The pages themselves, enlarged and out of focus, behind the phone.
struct BlurredPages: View {
    let image: NSImage
    var tone = 0.32

    var body: some View {
        ZStack {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: canvas.width, height: canvas.height)
                .scaleEffect(1.45)
                .blur(radius: 22, opaque: true)
            // A warm multiply keeps the paper reading as paper rather than grey.
            Color(red: 0.55, green: 0.40, blue: 0.26)
                .opacity(tone)
                .blendMode(.multiply)
            RadialGradient(colors: [.clear, .black.opacity(0.34)], center: .center, startRadius: 420, endRadius: 1050)
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
        .compositingGroup()
    }
}

struct Shot<Device: View>: View {
    let background: NSImage
    var tone = 0.32
    /// A soft light behind the phone, for dark pages where the frame would vanish.
    var glow = 0.0
    @ViewBuilder let device: Device

    var body: some View {
        ZStack {
            BlurredPages(image: background, tone: tone)
            RadialGradient(colors: [Color(red: 1, green: 0.9, blue: 0.75).opacity(glow), .clear], center: .center, startRadius: 120, endRadius: 760)
            device
                .shadow(color: .black.opacity(0.5), radius: 46, y: 30)
                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        }
        .frame(width: canvas.width, height: canvas.height)
    }
}

@MainActor
func render<V: View>(_ view: V, to name: String) {
    let renderer = ImageRenderer(content: view.frame(width: canvas.width, height: canvas.height))
    renderer.scale = renderScale
    guard let image = renderer.cgImage else { fatalError("Render failed for \(name)") }
    let bitmap = NSBitmapImageRep(cgImage: image)
    let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!
    try! data.write(to: output.appending(path: "\(name).jpg"))
    print("wrote marketing/twitter/\(name).jpg (\(image.width)×\(image.height), \(data.count / 1024) KB)")
}

MainActor.assumeIsolated {
    try! FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

    let hero = load("open-paper-hero")
    let pageThree = load("open-paper-p3")
    let closed = load("closed-paper-p3")
    let night = load("open-night-contents")
    let library = load("open-paper-library")
    let sepia = load("open-sepia-appearance")
    // The real half-open capture (with the system's crease blur) when there is one.
    let book = NSImage(contentsOf: raw.appending(path: "open-paper-book.png")) ?? hero

    render(Shot(background: hero) { OpenDuo(screen: hero, width: 1010) }, to: "01-spread")

    render(Shot(background: pageThree) {
        HStack(alignment: .center, spacing: 80) {
            ClosedDuo(screen: closed, width: 430)
            OpenDuo(screen: pageThree, width: 840)
        }
    }, to: "02-fold")

    render(Shot(background: night, tone: 0.1, glow: 0.16) { OpenDuo(screen: night, width: 1010) }, to: "03-contents")
    render(Shot(background: hero) { OpenDuo(screen: library, width: 1010) }, to: "04-library")
    render(Shot(background: sepia) { OpenDuo(screen: sepia, width: 1010) }, to: "05-appearance")
    render(Shot(background: book) { BookDuo(screen: book, width: 1000, angle: 24) }, to: "06-book-posture")
}
