import SwiftUI

/// The device's hinge, as far as the reader cares about it.
struct FoldContext: Equatable, Sendable {
    enum Status: Sendable {
        case unknown, closed, partiallyOpen, fullyOpen
    }

    var status: Status = .unknown
    /// Opening angle in degrees; 180 is flat.
    var angle: Double?

    /// 1 when the inner display is flat, falling to 0 as it folds towards 90°.
    var openness: Double {
        guard let angle else { return 1 }
        return min(max((angle - 90) / 90, 0), 1)
    }
}

extension EnvironmentValues {
    @Entry var foldContext = FoldContext()
    /// Set by the debug Duo harness to stand in for the system's division region.
    @Entry var simulatedCreaseWidth: CGFloat?
}

/// How a screen splits into pages: a spread either side of the fold (or the middle of a wide screen),
/// or a single page.
struct FoldLayout {
    let size: CGSize
    let isSpread: Bool
    let crease: CGRect

    init(proxy: GeometryProxy, simulatedCreaseWidth: CGFloat?) {
        size = proxy.size
        isSpread = size.width >= 640 && size.width > size.height * 1.15

        var division: CGRect?
        if let width = simulatedCreaseWidth {
            division = CGRect(x: (size.width - width) / 2, y: 0, width: width, height: size.height)
        } else if #available(iOS 27.1, *) {
            division = proxy.reservedRegions(kind: .division, options: .includeInactive)
                .map(\.frame)
                .first { $0.height > $0.width && $0.midX > 0 && $0.midX < proxy.size.width }
        }

        if isSpread {
            let fallback = CGRect(x: size.width / 2, y: 0, width: 0, height: size.height)
            crease = (division ?? fallback).intersection(CGRect(origin: .zero, size: size))
        } else {
            crease = .zero
        }
    }

    var leftPage: CGRect {
        CGRect(x: 0, y: 0, width: crease.minX, height: size.height)
    }

    var rightPage: CGRect {
        CGRect(x: crease.maxX, y: 0, width: size.width - crease.maxX, height: size.height)
    }
}

/// Publishes the real hinge state on iOS 27.1 and later. Earlier systems, and the debug harness,
/// leave whatever `foldContext` is already in the environment.
struct HingeReader: ViewModifier {
    @Environment(\.foldContext) private var inherited
    @State private var observed: FoldContext?

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content
                .environment(\.foldContext, observed ?? inherited)
                .onHingeChange { _, context in
                    observed = FoldContext(context)
                }
        } else {
            content
        }
    }
}

@available(iOS 27.1, *)
extension FoldContext {
    init?(_ context: DeviceHingeContext) {
        guard let hinge = context.hinge else { return nil }
        if hinge.status == .closed {
            status = .closed
        } else if hinge.status == .partiallyOpen {
            status = .partiallyOpen
        } else if hinge.status == .fullyOpen {
            status = .fullyOpen
        } else {
            status = .unknown
        }
        angle = hinge.angle.degrees
    }
}
