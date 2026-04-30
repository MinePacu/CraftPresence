import SwiftUI

struct NowPlayingTestView: View {
    var body: some View {
        ContentUnavailableView(
            "Now Playing",
            systemImage: "music.note",
            description: Text("iOS에서는 다른 앱의 Apple Music 재생 정보를 직접 읽을 수 없습니다.")
        )
        .padding()
    }
}
