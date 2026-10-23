import SwiftUI

enum ReaderPanel {
    case contents, appearance
}

struct ReaderView: View {
    let record: BookRecord
    var onClose: () -> Void

    @Environment(LibraryStore.self) private var library
    @Environment(ReaderSettings.self) private var settings
    @Environment(\.foldContext) private var fold
    @Environment(\.simulatedCreaseWidth) private var simulatedCreaseWidth

    @State private var model: ReaderModel
    @State private var chromeVisible = false
    @State private var panel: ReaderPanel?

    init(book: BookRecord, onClose: @escaping () -> Void) {
        record = book
        self.onClose = onClose
        _model = State(initialValue: ReaderModel(position: book.position))
    }

    var body: some View {
        GeometryReader { proxy in
            // Measured inside the safe area so the insets are known, then laid out over the whole screen.
            let fold = FoldLayout(proxy: proxy, simulatedCreaseWidth: simulatedCreaseWidth, fullScreen: true)
            let metrics = PageMetrics(fold: fold)
            let key = metrics.layoutKey(for: settings.style)

            ZStack(alignment: .topLeading) {
                if let book = model.book, let layout = model.layout {
                    pages(book: book, layout: layout, metrics: metrics)
                        .opacity(layout.key == key ? 1 : 0)
                        .animation(.easeOut(duration: 0.18), value: layout.key == key)
                } else {
                    loading
                        .frame(width: fold.size.width, height: fold.size.height)
                }

                if chromeVisible || panel != nil {
                    // Fades the text out under the controls so the glass sits on paper, not on lines of type.
                    let safe = fold.safeArea
                    edgeFade(
                        top: safe.top + (metrics.isSpread ? 104 : 112),
                        bottom: safe.bottom + (metrics.isSpread ? 104 : 156),
                        size: fold.size
                    )
                }

                if let book = model.book, let layout = model.layout, layout.key == key {
                    if metrics.isSpread {
                        spreadChrome(book: book, layout: layout, metrics: metrics)
                    } else {
                        closedChrome(book: book, layout: layout, metrics: metrics)
                    }
                }
            }
            .frame(width: fold.size.width, height: fold.size.height, alignment: .topLeading)
            .ignoresSafeArea()
            .task(id: key) {
                #if DEBUG
                if ProcessInfo.processInfo.environment["FOLIO_PROBE"] == "1" {
                    print("[probe] reader screen=\(fold.size) safe=\(fold.safeArea) spread=\(metrics.isSpread) crease=\(fold.crease) text=\(metrics.textSize)")
                }
                #endif
                await model.prepare(url: library.epubURL(for: record), key: key)
            }
        }
        .background(settings.theme.paper.ignoresSafeArea())
        .environment(\.colorScheme, settings.theme.colorScheme)
        .tint(settings.theme.ink)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .animation(.smooth(duration: 0.25), value: chromeVisible)
        .animation(.smooth(duration: 0.3), value: panel)
        .onAppear {
            library.markOpened(record.id)
            #if DEBUG
            chromeVisible = DebugFlags.chrome
            switch DebugFlags.panel {
            case "contents": panel = .contents
            case "appearance": panel = .appearance
            default: break
            }
            #endif
        }
        .onChange(of: model.position) { _, position in
            library.updateReading(record.id, position: position, progress: model.progress)
        }
    }

    // MARK: - Pages

    @ViewBuilder
    private func pages(book: LoadedBook, layout: BookLayout, metrics: PageMetrics) -> some View {
        let dismissing = chromeVisible || panel != nil
        if metrics.isSpread {
            Pager(
                count: (layout.pages.count + 1) / 2,
                index: Binding(get: { model.page / 2 }, set: { model.show(page: $0 * 2) }),
                capturesTaps: dismissing,
                onCenterTap: toggleChrome
            ) { spread in
                SpreadView(layout: layout, book: book, leftIndex: spread * 2, metrics: metrics, theme: settings.theme)
                    .background(settings.theme.paper)
            }
            .overlay(alignment: .topLeading) {
                GutterShade(theme: settings.theme, openness: fold.openness)
                    .frame(width: metrics.fold.crease.width + 72)
                    .frame(maxHeight: .infinity)
                    .offset(x: metrics.fold.crease.minX - 36)
                    .ignoresSafeArea(edges: .vertical)
                    .allowsHitTesting(false)
            }
        } else {
            Pager(
                count: layout.pages.count,
                index: Binding(get: { model.page }, set: { model.show(page: $0) }),
                capturesTaps: dismissing,
                onCenterTap: toggleChrome
            ) { page in
                PageView(layout: layout, book: book, index: page, side: .single, metrics: metrics, theme: settings.theme)
                    .background(settings.theme.paper)
            }
        }
    }

    private var loading: some View {
        VStack(spacing: 14) {
            if let failure = model.failure {
                Text("This book could not be opened.")
                    .font(.system(.title3, design: .serif))
                Text(failure)
                    .font(.callout)
                    .foregroundStyle(settings.theme.secondaryInk)
                    .multilineTextAlignment(.center)
                Button("Back to Library", action: onClose)
                    .buttonStyle(.glass)
                    .padding(.top, 8)
            } else {
                Text(record.title)
                    .font(.system(.title2, design: .serif))
                    .multilineTextAlignment(.center)
                ProgressView()
            }
        }
        .foregroundStyle(settings.theme.ink)
        .padding(32)
    }

    private func edgeFade(top: CGFloat, bottom: CGFloat, size: CGSize) -> some View {
        let paper = settings.theme.paper
        let stops: [Gradient.Stop] = [
            .init(color: paper, location: 0),
            .init(color: paper.opacity(0.96), location: 0.68),
            .init(color: paper.opacity(0), location: 1),
        ]
        return VStack(spacing: 0) {
            LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
                .frame(height: top)
            Spacer(minLength: 0)
            LinearGradient(stops: stops, startPoint: .bottom, endPoint: .top)
                .frame(height: bottom)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func toggleChrome() {
        if panel != nil {
            panel = nil
        } else {
            chromeVisible.toggle()
        }
    }

    // MARK: - Open: chrome that keeps clear of the fold

    @ViewBuilder
    private func spreadChrome(book: LoadedBook, layout: BookLayout, metrics: PageMetrics) -> some View {
        let fold = metrics.fold
        let safe = fold.safeArea
        let inset: CGFloat = 14

        if chromeVisible || panel != nil {
            // Left page: way out, and where you are.
            VStack(alignment: .leading) {
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        GlassIconButton(systemName: "chevron.backward", label: "Library", action: onClose)
                        Text(book.title)
                            .font(.system(size: 15, weight: .medium, design: .serif))
                            .lineLimit(1)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .glassEffect(.regular, in: .capsule)
                    }
                }
                Spacer()
                if panel == nil {
                    locationLabel(layout: layout, book: book)
                }
            }
            .padding(inset)
            .padding(EdgeInsets(top: safe.top, leading: safe.leading, bottom: safe.bottom, trailing: 0))
            .frame(width: fold.leftPage.width, height: fold.size.height, alignment: .leading)
            .transition(.opacity)

            // Right page: tools, and the scrubber under the reading hand.
            VStack(alignment: .trailing) {
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        GlassIconButton(systemName: "list.bullet", label: "Contents", isSelected: panel == .contents) {
                            panel = panel == .contents ? nil : .contents
                        }
                        GlassIconButton(systemName: "textformat.size", label: "Appearance", isSelected: panel == .appearance) {
                            panel = panel == .appearance ? nil : .appearance
                        }
                    }
                }
                Spacer()
                if panel == nil {
                    scrubber(layout: layout, pagesPerStep: 2)
                }
            }
            .padding(inset)
            .padding(EdgeInsets(top: safe.top, leading: 0, bottom: safe.bottom, trailing: safe.trailing))
            .frame(width: fold.rightPage.width, height: fold.size.height, alignment: .trailing)
            .offset(x: fold.rightPage.minX)
            .transition(.opacity)
        }

        if panel == .contents {
            ContentsPanel(book: book, layout: layout, currentPage: model.page) { chapter in
                model.show(chapter: chapter)
                panel = nil
                chromeVisible = false
            } onClose: {
                panel = nil
            }
            .padding(.top, 72)
            .padding([.horizontal, .bottom], inset)
            .padding(EdgeInsets(top: safe.top, leading: safe.leading, bottom: safe.bottom, trailing: 0))
            .frame(width: fold.leftPage.width, height: fold.size.height)
            .transition(.move(edge: .leading).combined(with: .opacity))
        }

        if panel == .appearance {
            AppearancePanel { panel = nil }
                .frame(width: min(360, fold.rightPage.width - inset * 2))
                .padding(.top, 72)
                .padding(inset)
                .padding(EdgeInsets(top: safe.top, leading: 0, bottom: safe.bottom, trailing: safe.trailing))
                .frame(width: fold.rightPage.width, height: fold.size.height, alignment: .topTrailing)
                .offset(x: fold.rightPage.minX)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    // MARK: - Closed: one page, controls within reach of the thumb

    @ViewBuilder
    private func closedChrome(book: LoadedBook, layout: BookLayout, metrics: PageMetrics) -> some View {
        let size = metrics.fold.size

        if chromeVisible || panel != nil {
            VStack(spacing: 0) {
                HStack {
                    GlassIconButton(systemName: "chevron.backward", label: "Library", action: onClose)
                    Spacer()
                    Text(book.title(forChapter: layout.pages[safe: model.page]?.chapter ?? 0) ?? book.title)
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .glassEffect(.regular, in: .capsule)
                    Spacer()
                    GlassIconButton(systemName: "textformat.size", label: "Appearance", isSelected: panel == .appearance) {
                        panel = panel == .appearance ? nil : .appearance
                    }
                }
                Spacer()
                if panel == nil {
                    GlassEffectContainer(spacing: 10) {
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                GlassIconButton(systemName: "list.bullet", label: "Contents") {
                                    panel = .contents
                                }
                                scrubber(layout: layout, pagesPerStep: 1)
                            }
                            locationLabel(layout: layout, book: book)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .padding(metrics.fold.safeArea)
            .frame(width: size.width, height: size.height)
            .transition(.opacity)
        }

        if let panel {
            VStack {
                Spacer()
                Group {
                    switch panel {
                    case .contents:
                        ContentsPanel(book: book, layout: layout, currentPage: model.page) { chapter in
                            model.show(chapter: chapter)
                            self.panel = nil
                            chromeVisible = false
                        } onClose: {
                            self.panel = nil
                        }
                        .frame(height: size.height * 0.68)
                    case .appearance:
                        AppearancePanel { self.panel = nil }
                    }
                }
            }
            .padding(10)
            .padding(metrics.fold.safeArea)
            .frame(width: size.width, height: size.height)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Shared controls

    private func scrubber(layout: BookLayout, pagesPerStep: Int) -> some View {
        let last = max(layout.pages.count - 1, 1)
        return Slider(
            value: Binding(
                get: { Double(model.page) },
                set: { model.show(page: Int($0.rounded()) / pagesPerStep * pagesPerStep) }
            ),
            in: 0...Double(last)
        )
        .padding(.horizontal, 18)
        .frame(maxWidth: 380)
        .frame(height: 44)
        .glassEffect(.regular, in: .capsule)
        .accessibilityLabel("Page")
        .accessibilityValue("\(model.page + 1) of \(layout.pages.count)")
    }

    private func locationLabel(layout: BookLayout, book: LoadedBook) -> some View {
        let left = layout.pagesLeftInChapter(from: model.page)
        let detail = left == 0 ? "Last page in chapter" : left == 1 ? "1 page left in chapter" : "\(left) pages left in chapter"
        return HStack(spacing: 8) {
            Text("\(model.page + 1) of \(layout.pages.count)")
                .monospacedDigit()
            Text("·")
                .foregroundStyle(.secondary)
            Text(detail)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 13))
        .lineLimit(1)
        .padding(.horizontal, 14)
        .frame(height: 32)
        .glassEffect(.regular, in: .capsule)
    }
}

/// A circular Liquid Glass button for an SF Symbol.
struct GlassIconButton: View {
    let systemName: String
    let label: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(isSelected ? .regular.tint(.accentColor.opacity(0.35)).interactive() : .regular.interactive(), in: .circle)
        .accessibilityLabel(label)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
