import SwiftUI

struct ContentsPanel: View {
    let book: LoadedBook
    let layout: BookLayout
    let currentPage: Int
    let onSelect: (Int) -> Void
    let onClose: () -> Void

    var body: some View {
        let currentChapter = layout.pages[safe: currentPage]?.chapter ?? 0
        let currentEntry = book.contents.last { $0.chapter <= currentChapter }?.id

        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(title: "Contents", onClose: onClose)

            ScrollViewReader { scroller in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(book.contents) { entry in
                            Button {
                                onSelect(entry.chapter)
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(entry.title)
                                        .font(.system(size: entry.depth == 0 ? 16 : 15, design: .serif))
                                        .foregroundStyle(entry.depth == 0 ? .primary : .secondary)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 8)
                                    if layout.chapterFirstPage.indices.contains(entry.chapter) {
                                        Text("\(layout.chapterFirstPage[entry.chapter] + 1)")
                                            .font(.system(size: 13).monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.leading, CGFloat(entry.depth) * 16)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .background {
                                    if entry.id == currentEntry {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(.primary.opacity(0.07))
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(entry.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    if let currentEntry { scroller.scrollTo(currentEntry, anchor: .center) }
                }
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct AppearancePanel: View {
    let onClose: () -> Void
    @Environment(ReaderSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 18) {
            PanelHeader(title: "Appearance", onClose: onClose)
                .padding(.horizontal, -6)

            HStack(spacing: 10) {
                Button {
                    settings.adjustSize(by: -1)
                } label: {
                    Image(systemName: "textformat.size.smaller")
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .accessibilityLabel("Smaller text")
                Text("\(Int(settings.fontSize))")
                    .font(.system(size: 15).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36)
                Button {
                    settings.adjustSize(by: 1)
                } label: {
                    Image(systemName: "textformat.size.larger")
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .accessibilityLabel("Larger text")
            }
            .buttonStyle(.glass)

            HStack(spacing: 12) {
                ForEach(ReaderTheme.allCases) { theme in
                    Button {
                        settings.theme = theme
                    } label: {
                        Text("Aa")
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(theme.ink)
                            .frame(width: 46, height: 46)
                            .background(theme.paper, in: Circle())
                            .overlay {
                                Circle().strokeBorder(
                                    settings.theme == theme ? Color.accentColor : Color.primary.opacity(0.15),
                                    lineWidth: settings.theme == theme ? 2 : 1
                                )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(theme.name)
                    .accessibilityAddTraits(settings.theme == theme ? .isSelected : [])
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                ForEach(ReaderFont.allCases) { font in
                    Button {
                        settings.font = font
                    } label: {
                        HStack {
                            Text(font.name)
                                .font(font.font(size: 17))
                            Spacer()
                            if settings.font == font {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Picker("Line spacing", selection: $settings.spacing) {
                ForEach(LineSpacing.allCases) { spacing in
                    Text(spacing.name).tag(spacing)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Justify text", isOn: $settings.justified)
                .font(.system(size: 15))
                .padding(.horizontal, 4)
        }
        .padding(18)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct PanelHeader: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .serif))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }
}
