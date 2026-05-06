import SwiftUI

#if os(iOS)
import UIKit
#endif

struct CPSettingsPage<Content: View>: View {
    let horizontalPadding: CGFloat
    let maximumContentWidth: CGFloat?
    @ViewBuilder var content: () -> Content
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    init(
        horizontalPadding: CGFloat = 20,
        maximumContentWidth: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.horizontalPadding = horizontalPadding
        self.maximumContentWidth = maximumContentWidth
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                content()
            }
            .frame(maxWidth: resolvedMaximumContentWidth, alignment: .leading)
            .padding(.horizontal, resolvedHorizontalPadding)
            .padding(.top, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(CPStyle.pageBackground.ignoresSafeArea())
    }

    private var resolvedHorizontalPadding: CGFloat {
#if os(iOS)
        horizontalSizeClass == .compact ? horizontalPadding : max(horizontalPadding, 32)
#else
        horizontalPadding
#endif
    }

    private var resolvedMaximumContentWidth: CGFloat? {
#if os(iOS)
        maximumContentWidth ?? (horizontalSizeClass == .compact ? nil : 760)
#else
        maximumContentWidth
#endif
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

struct CPToastMessage: Identifiable, Equatable {
    enum Style: Equatable {
        case success
        case info
    }

    let id = UUID()
    let text: String
    var style: Style = .success
}

private struct CPToastModifier: ViewModifier {
    @Binding var message: CPToastMessage?

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .task(id: message?.id) {
                guard let current = message else {
                    await CPToastWindowPresenter.shared.dismiss()
                    return
                }
                await CPToastWindowPresenter.shared.show(current)
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                await MainActor.run {
                    if message?.id == current.id {
                        message = nil
                    }
                }
                await CPToastWindowPresenter.shared.dismiss(id: current.id)
            }
        #else
        ZStack(alignment: .bottom) {
            content

            if let message {
                CPToastView(message: message)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.snappy(duration: 0.24), value: message?.id)
        .task(id: message?.id) {
            guard let current = message else { return }
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            await MainActor.run {
                if message?.id == current.id {
                    message = nil
                }
            }
        }
        #endif
    }
}

private struct CPToastView: View {
    let message: CPToastMessage

    var body: some View {
        Label(message.text, systemImage: systemImage)
            .font(.callout.weight(.semibold))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: 420, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
            .symbolRenderingMode(.hierarchical)
            .tint(tint)
    }

    private var systemImage: String {
        switch message.style {
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }

    private var tint: Color {
        switch message.style {
        case .success:
            return .green
        case .info:
            return .blue
        }
    }
}

extension View {
    func cpToast(_ message: Binding<CPToastMessage?>) -> some View {
        modifier(CPToastModifier(message: message))
    }
}

#if os(iOS)
@MainActor
private final class CPToastWindowPresenter {
    static let shared = CPToastWindowPresenter()

    private var window: UIWindow?
    private var currentID: UUID?

    private init() {}

    func show(_ message: CPToastMessage) {
        if currentID == message.id {
            return
        }

        guard let windowScene = activeWindowScene else { return }
        let toastWindow = window ?? CPToastPassThroughWindow(windowScene: windowScene)
        toastWindow.windowLevel = .alert + 1
        toastWindow.backgroundColor = .clear
        toastWindow.rootViewController = UIHostingController(rootView: CPToastWindowRoot(message: message))
        toastWindow.rootViewController?.view.backgroundColor = .clear
        toastWindow.isHidden = false
        window = toastWindow
        currentID = message.id
    }

    func dismiss(id: UUID? = nil) {
        if let id, currentID != id {
            return
        }

        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        currentID = nil
    }

    private var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }
}

private final class CPToastPassThroughWindow: UIWindow {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        false
    }
}

private struct CPToastWindowRoot: View {
    let message: CPToastMessage
    @State private var isVisible = false

    var body: some View {
        VStack {
            Spacer()
            CPToastView(message: message)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.snappy(duration: 0.24)) {
                isVisible = true
            }
        }
    }
}
#endif

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
