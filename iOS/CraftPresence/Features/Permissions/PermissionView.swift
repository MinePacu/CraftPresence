import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        ContentUnavailableView(
            localizationManager.string("permissions.title"),
            systemImage: "hand.raised",
            description: Text(localizationManager.string("permissions.message"))
        )
        .padding()
    }
}

struct ThemedButtonStyle: ButtonStyle {
    let fontSize: CGFloat
    let width: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .frame(width: width, height: 36)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.7 : 1.0), in: RoundedRectangle(cornerRadius: 8))
            .foregroundColor(.white)
    }
}
