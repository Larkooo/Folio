// Composes Twitter images from raw iPhone Duo simulator captures: the Duo, drawn from the simulator's own
// device artwork, in front of the same pages enlarged and blurred.
// Run from the repository root:  swift marketing/compose.swift
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

// MARK: - Device

/// The iPhone Duo's chrome as Xcode's DeviceKit ships it (vector PDFs), with sizes from its chrome.json and
/// the device type's display corner radii. Units are device points.
enum Duo {
    static let chromeDirectory = URL(fileURLWithPath: "/Library/Developer/DeviceKit/Chrome/phone15.devicechrome/Contents/Resources")

    static func artwork(_ name: String) -> NSImage {
        guard let image = NSImage(contentsOf: chromeDirectory.appending(path: "\(name).pdf")) else {
            fatalError("Missing Duo chrome \(name).pdf; install the iOS 27.1 simulator runtime")
        }
        return image
    }

    static let body = artwork("PhoneComposite")
    static let volumeButton = artwork("Vol BTN")
    static let powerButton = artwork("X_Power BTN")

    /// The closed phone. The back half peeks out along the hinge on the leading edge.
    static let half = CGSize(width: 514, height: 706)
    static let outerScreen = CGRect(x: 26, y: 14, width: 466, height: 678)
    static let innerScreen = CGSize(width: 951, height: 669)
    /// The front half alone, without the back half's edge. Open, two of these meet at the hinge, where their
    /// small corner radii leave the notch DeviceHub shows at the top and bottom.
    static let frontWidth: CGFloat = 502.5
    static var open: CGSize { CGSize(width: frontWidth * 2, height: half.height) }

    static let volumeOffsets: [CGFloat] = [236, 316]
    static let volumeSize = CGSize(width: 66, height: 16)
    static let sideButtons: [(y: CGFloat, height: CGFloat)] = [(202, 113), (460, 102)]
    static let buttonWidth: CGFloat = 16
    /// How far a button stands out from the body.
    static let buttonRise: CGFloat = 3.5
}

/// Positions a view by its top-leading corner inside a fixed-size frame.
extension View {
    func place(_ rect: CGRect, scale s: CGFloat) -> some View {
        frame(width: rect.width * s, height: rect.height * s)
            .offset(x: rect.minX * s, y: rect.minY * s)
    }
}

/// The buttons on the half that carries the outer screen: volume on the top edge, two on the outer side.
/// They sit behind the body and stand out by `buttonRise`.
struct DuoButtons: View {
    /// Where the closed-phone artwork for this half starts.
    let halfOriginX: CGFloat
    let scale: CGFloat

    var body: some View {
        let rightEdge = halfOriginX + Duo.half.width
        ZStack(alignment: .topLeading) {
            ForEach(Duo.volumeOffsets, id: \.self) { x in
                Image(nsImage: Duo.volumeButton)
                    .resizable()
                    .place(CGRect(x: halfOriginX + x, y: 1 - Duo.buttonRise, width: Duo.volumeSize.width, height: Duo.volumeSize.height), scale: scale)
            }
            ForEach(Duo.sideButtons, id: \.y) { button in
                Image(nsImage: Duo.powerButton)
                    .resizable()
                    .place(CGRect(x: rightEdge - 1 + Duo.buttonRise - Duo.buttonWidth, y: button.y, width: Duo.buttonWidth, height: button.height), scale: scale)
            }
        }
    }
}

struct ClosedDuo: View {
    let screen: NSImage
    let scale: CGFloat

    var body: some View {
        let s = scale
        ZStack(alignment: .topLeading) {
            DuoButtons(halfOriginX: 0, scale: s)
            Image(nsImage: Duo.body)
                .resizable()
                .place(CGRect(origin: .zero, size: Duo.half), scale: s)
            Image(nsImage: screen)
                .resizable()
                .interpolation(.high)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 8 * s,
                    bottomLeadingRadius: 8 * s,
                    bottomTrailingRadius: 59 * s,
                    topTrailingRadius: 59 * s,
                    style: .continuous
                ))
                .place(Duo.outerScreen, scale: s)
        }
        .frame(width: Duo.half.width * s, height: Duo.half.height * s, alignment: .topLeading)
    }
}

struct OpenDuo: View {
    let screen: NSImage
    let scale: CGFloat
    /// 0 is flat. Above 0, the left half is folded away from the viewer: blurred and shaded, as DeviceHub
    /// shows the Duo part-closed.
    var fold: Double = 0

    var body: some View {
        let s = scale
        let size = Duo.open
        let spine = Duo.half.width - Duo.frontWidth
        let screenRect = CGRect(
            x: (size.width - Duo.innerScreen.width) / 2,
            y: (size.height - Duo.innerScreen.height) / 2,
            width: Duo.innerScreen.width,
            height: Duo.innerScreen.height
        )
        let screenShape = RoundedRectangle(cornerRadius: 55 * s, style: .continuous)

        ZStack(alignment: .topLeading) {
            DuoButtons(halfOriginX: Duo.frontWidth - spine, scale: s)
            // Left half: the artwork mirrored, keeping only the front half.
            Image(nsImage: Duo.body)
                .resizable()
                .frame(width: Duo.half.width * s, height: Duo.half.height * s)
                .scaleEffect(x: -1, y: 1)
                .frame(width: Duo.frontWidth * s, alignment: .leading)
                .clipped()
            // Right half, the one with the buttons.
            Image(nsImage: Duo.body)
                .resizable()
                .frame(width: Duo.half.width * s, height: Duo.half.height * s)
                .frame(width: Duo.frontWidth * s, alignment: .trailing)
                .clipped()
                .offset(x: Duo.frontWidth * s)
            // The artwork's cutout is shaped for the outer screen; open, the black border runs unbroken
            // around the inner screen and across the hinge.
            RoundedRectangle(cornerRadius: 66 * s, style: .continuous)
                .fill(Color.black)
                .place(screenRect.insetBy(dx: -11, dy: -11), scale: s)
            ZStack {
                Image(nsImage: screen)
                    .resizable()
                    .interpolation(.high)
                if fold > 0 {
                    FoldedHalf(screen: screen, fold: fold, scale: s)
                }
            }
            .clipShape(screenShape)
            .place(screenRect, scale: s)
        }
        .frame(width: size.width * s, height: size.height * s, alignment: .topLeading)
    }
}

/// The left half of the inner screen turned away from the viewer: out of focus, darker toward its outer edge
/// and along the top and bottom where the panel bends away.
struct FoldedHalf: View {
    let screen: NSImage
    let fold: Double
    let scale: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let half = proxy.size.width / 2
            ZStack(alignment: .leading) {
                Image(nsImage: screen)
                    .resizable()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .blur(radius: 9 * scale * fold, opaque: true)
                    .frame(width: half, height: proxy.size.height, alignment: .leading)
                    .clipped()
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.88 * fold), location: 0),
                        .init(color: .black.opacity(0.55 * fold), location: 0.25),
                        .init(color: .black.opacity(0.15 * fold), location: 0.62),
                        .init(color: .black.opacity(0.02 * fold), location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: half)
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.55 * fold), location: 0),
                        .init(color: .clear, location: 0.22),
                        .init(color: .clear, location: 0.78),
                        .init(color: .black.opacity(0.55 * fold), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: half)
                .mask(LinearGradient(colors: [.black, .black.opacity(0.2)], startPoint: .leading, endPoint: .trailing))
            }
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

    let single: CGFloat = 1.06 // the open Duo about 1060 pt wide on a 1600 pt canvas

    render(Shot(background: hero) { OpenDuo(screen: hero, scale: single) }, to: "01-spread")

    // Both phones at the same scale, so the closed one reads as the same device folded.
    render(Shot(background: pageThree) {
        HStack(alignment: .center, spacing: 70) {
            ClosedDuo(screen: closed, scale: 0.92)
            OpenDuo(screen: pageThree, scale: 0.92)
        }
    }, to: "02-fold")

    render(Shot(background: night, tone: 0.1, glow: 0.16) { OpenDuo(screen: night, scale: single) }, to: "03-contents")
    render(Shot(background: hero) { OpenDuo(screen: library, scale: single) }, to: "04-library")
    render(Shot(background: sepia) { OpenDuo(screen: sepia, scale: single) }, to: "05-appearance")
}
