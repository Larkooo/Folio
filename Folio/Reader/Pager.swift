import SwiftUI

/// Horizontal paging over a large number of views, keeping only the current one and its neighbours alive.
/// Pages follow the finger, and taps near either edge turn the page.
struct Pager<Content: View>: View {
    let count: Int
    @Binding var index: Int
    /// While true, every tap goes to `onCenterTap` (used to dismiss the controls).
    var capturesTaps = false
    var onCenterTap: () -> Void = {}
    @ViewBuilder var content: (Int) -> Content

    @State private var drag: CGFloat = 0
    @State private var isTurning = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                ForEach(visibleIndices, id: \.self) { page in
                    content(page)
                        .frame(width: width, height: proxy.size.height)
                        .offset(x: CGFloat(page - index) * width + drag)
                }
            }
            .frame(width: width, height: proxy.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(dragGesture(width: width))
            .onTapGesture(coordinateSpace: .local) { location in
                handleTap(at: location.x, width: width)
            }
        }
        .clipped()
    }

    private var visibleIndices: [Int] {
        [index - 1, index, index + 1].filter { $0 >= 0 && $0 < count }
    }

    private func handleTap(at x: CGFloat, width: CGFloat) {
        if capturesTaps {
            onCenterTap()
        } else if x < width * 0.28 {
            turn(by: -1, width: width)
        } else if x > width * 0.72 {
            turn(by: 1, width: width)
        } else {
            onCenterTap()
        }
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isTurning else { return }
                let translation = value.translation.width
                let atEdge = (translation > 0 && index == 0) || (translation < 0 && index >= count - 1)
                drag = atEdge ? translation * 0.25 : translation
            }
            .onEnded { value in
                guard !isTurning else { return }
                let travel = value.predictedEndTranslation.width
                if (travel < -width * 0.35 || value.translation.width < -width * 0.25), index < count - 1 {
                    turn(by: 1, width: width)
                } else if (travel > width * 0.35 || value.translation.width > width * 0.25), index > 0 {
                    turn(by: -1, width: width)
                } else {
                    withAnimation(.snappy(duration: 0.25)) { drag = 0 }
                }
            }
    }

    private func turn(by step: Int, width: CGFloat) {
        let target = index + step
        guard target >= 0, target < count, !isTurning else { return }
        isTurning = true
        withAnimation(.smooth(duration: 0.32)) {
            drag = -CGFloat(step) * width
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                index = target
                drag = 0
            }
            isTurning = false
        }
    }
}
