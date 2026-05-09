# CraftPresence

한국어 | [English](README.en.md)

CraftPresence는 Discord Rich Presence를 여러 플랫폼에서 사용할 수 있도록 개발 중인 멀티 플랫폼 프로젝트입니다. 현재 저장소에는 Android, macOS, iOS 앱과 각 기기를 통합 관리하기 위한 웹 기반 매니저가 함께 들어 있습니다.

각 네이티브 앱은 Discord 계정 연결, Presence 상태 게시, 앱 또는 사용자 활동 정보를 Discord 프로필에 표시하는 기능을 담당합니다. 웹 매니저는 여러 기기의 등록 상태, Presence 우선순위, 설정 백업, Discord 이미지 자산, Presence 변경 기록을 한곳에서 관리하는 서버형 콘솔입니다.

## 프로젝트 구성

| 구성 요소 | 설명 | 문서 |
| --- | --- | --- |
| Android | 현재 전면 앱과 음악 재생 정보를 감지해 Discord Rich Presence로 표시하는 Android 앱 | [Android README](Android/README.md) |
| macOS | 실행 중인 macOS 애플리케이션을 추적하고 Discord Rich Presence를 자동으로 갱신하는 네이티브 macOS 앱 | [macOS README](macOS/README.md) |
| iOS | iPhone과 iPad에서 사용자 정의 Presence 프리셋을 만들고 Discord 활동으로 게시하는 SwiftUI 앱 | [iOS README](iOS/README.md) |
| Web Manager | 등록된 CraftPresence 기기, 설정 백업, Discord 이미지 자산, Presence 기록과 동기화 상태를 관리하는 Docker 기반 웹 콘솔 | `web/` |

## 주요 기능

- Discord 계정 인증 및 Rich Presence 게시
- 플랫폼별 앱 사용 상태 또는 사용자 정의 Presence 표시
- 음악 재생 정보, 앱 이름, 창 제목, 프리셋 상태 등 활동 정보 반영
- Presence 문구, 활동 타입, 이미지 키, 파티 정보 등 커스터마이징
- 설정 백업 JSON 내보내기, 가져오기, 검증 및 원격 관리
- 여러 기기 간 Presence 우선순위 관리와 현재 Presence 상태 동기화
- Discord Rich Presence용 큰/작은 이미지 키와 이미지 텍스트를 관리하는 이미지 자산 저장소
- 전체 또는 기기별 Presence 변경 기록 조회
- 한국어와 영어를 포함한 다국어 UI 리소스
- 플랫폼별 권한 안내와 연결 상태 확인 화면

## 저장소 구조

```text
CraftPresence-work/
├── Android/  # Kotlin, Jetpack Compose 기반 Android 앱
├── macOS/    # SwiftUI 기반 macOS 앱
├── iOS/      # SwiftUI 기반 iPhone/iPad 앱
└── web/      # React, Fastify, PostgreSQL 기반 웹 매니저
```

## 기술 스택

- **Android**: Kotlin, Jetpack Compose, Android SDK, Discord Partner SDK
- **macOS**: Swift, SwiftUI, Swift/C++ Interoperability, macOS Accessibility API, Discord Partner SDK
- **iOS**: Swift, SwiftUI, Discord Partner SDK
- **Web Manager**: TypeScript, React, Vite, Fastify, PostgreSQL, Drizzle ORM, Docker Compose

## 시작하기

각 플랫폼과 웹 매니저는 빌드 도구와 로컬 설정 방식이 다릅니다. 작업하려는 디렉터리의 README 또는 설정 파일을 먼저 확인하세요.

- [Android 시작하기](Android/README.md#설정)
- [macOS 시작하기](macOS/README.md#설치-및-빌드)
- [iOS 시작하기](iOS/README.md#시작하기)
- 웹 매니저 실행: `cd web && docker compose up --build`

Discord 연동을 위해서는 공통적으로 Discord Developer Portal에서 만든 Application ID가 필요합니다. 실제 Application ID나 로컬 설정 파일은 저장소에 커밋하지 않는 방식으로 관리합니다.

웹 매니저는 기본적으로 `http://localhost:8080`에서 실행됩니다. 호스트 포트를 바꾸려면 `web/docker-compose.yml`의 `ports` 항목에서 앞쪽 포트만 변경하세요. 예를 들어 `8081:8080`으로 바꾸면 `http://localhost:8081`로 접속할 수 있습니다.

## 개발 메모

- 이 저장소는 플랫폼별 구현을 한곳에서 관리하는 구조입니다.
- Android는 전면 앱 감지와 음악 재생 정보 기반 Presence에 초점이 있습니다.
- macOS는 Accessibility 권한을 통한 실행 앱 추적과 프로그램별 Presence 설정에 초점이 있습니다.
- iOS는 사용자가 직접 만드는 Presence 프리셋 게시 흐름에 초점이 있습니다.
- Web Manager는 여러 기기를 한 계정 아래에서 관리하고, 설정 백업과 Presence 이벤트를 서버에서 통합 관리하는 흐름에 초점이 있습니다.
- 현재 앱 지원 대상은 Android, macOS, iOS이며 웹 매니저의 데이터 구조는 추후 Windows와 Linux 기기 추가를 고려해 구성되어 있습니다.

## 라이선스

플랫폼별 라이선스 파일을 확인하세요.

- [Android LICENSE](Android/LICENSE)
- [iOS LICENSE](iOS/LICENSE)
