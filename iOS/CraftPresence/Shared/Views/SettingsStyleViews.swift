import SwiftUI

#if os(iOS)
import UIKit
#endif

struct CPSettingsPage<Content: View>: View {
    let horizontalPadding: CGFloat
    @ViewBuilder var content: () -> Content

    init(horizontalPadding: CGFloat = 20, @ViewBuilder content: @escaping () -> Content) {
        self.horizontalPadding = horizontalPadding
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                content()
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(CPStyle.pageBackground.ignoresSafeArea())
    }
}

struct CPHeaderCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.gradient)
                .frame(width: 62, height: 62)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(CPStyle.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct CPGroupedSection<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CPStyle.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct CPSettingsRow<Accessory: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    var tint: Color = .accentColor
    @ViewBuilder var accessory: () -> Accessory

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        tint: Color = .accentColor,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 14) {
            CPRowIcon(systemImage: systemImage, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)
            accessory()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension CPSettingsRow where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil, systemImage: String, tint: Color = .accentColor) {
        self.init(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint) {
            EmptyView()
        }
    }
}

struct CPNavigationRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        CPSettingsRow(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint) {
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

struct CPSectionDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 64)
    }
}

struct CPRowIcon: View {
    let systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(tint.gradient)
            .frame(width: 30, height: 30)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

enum CPStyle {
    static var pageBackground: Color {
#if os(iOS)
        Color(uiColor: .systemGroupedBackground)
#elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        Color(.systemBackground)
#endif
    }

    static var cardBackground: Color {
#if os(iOS)
        Color(uiColor: .secondarySystemGroupedBackground)
#elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
#else
        Color.secondary.opacity(0.08)
#endif
    }
}
