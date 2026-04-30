# CraftPresence

[English](README.en.md) | 한국어

CraftPresence는 iPhone과 iPad에서 Discord Rich Presence를 직접 설정하고 게시하기 위한 SwiftUI 앱입니다. 사용자가 프리셋을 만들고, Discord 계정으로 인증한 뒤, 선택한 상태 메시지를 Discord 활동으로 표시할 수 있도록 구성되어 있습니다.

## 주요 기능

- Discord Partner SDK 기반 인증 및 Rich Presence 게시
- 사용자 정의 Presence 프리셋 생성, 수정, 삭제
- 활동 유형, 상세 메시지, 상태 메시지, 이미지 키, 파티 정보, 경과 시간 설정
- Discord 연결 상태, 인증 사용자, 활성 프리셋을 보여주는 개요 화면
- 한국어, 영어, 일본어 로컬라이징 리소스
- UI 테스트용 자동화 설정 시드 지원

## 프로젝트 구조

```text
CraftPresence/
├── App/                         앱 진입점과 플랫폼별 부트스트랩
├── Features/
│   ├── Discord/                 Discord 인증, SDK 연동, 테스트 화면
│   ├── Overview/                상태 대시보드
│   ├── Permissions/             권한 안내 화면
│   ├── Presence/                내장 Presence 관련 코드
│   └── Programs/                Presence 프리셋 관리 화면
├── Shared/                      공통 모델, 설정 저장소, 로컬라이징, 루트 뷰
├── ThirdParty/DiscordSocialSDK/ Discord Partner SDK XCFramework
├── en.lproj/
├── ja.lproj/
└── ko.lproj/
```

## 요구 사항

- Xcode가 설치된 macOS 개발 환경
- Swift 5 기반 Xcode 프로젝트
- iPhone 또는 iPad 시뮬레이터/기기
- Discord Developer Portal에서 만든 애플리케이션 ID

프로젝트 파일에는 현재 iOS 배포 타깃이 `26.4`로 설정되어 있습니다. 사용하는 Xcode와 SDK 버전에 맞지 않으면 Xcode의 target build settings에서 배포 타깃을 조정하세요.

## 시작하기

1. 저장소를 클론합니다.

   ```bash
   git clone <repository-url>
   cd CraftPresence
   ```

2. `CraftPresence.xcodeproj`를 Xcode에서 엽니다.

3. `CraftPresence` 타깃의 `APPLICATION_ID` 값이 본인의 Discord 애플리케이션 ID인지 확인합니다.

4. Discord Developer Portal에서 Redirect URI 또는 URL Scheme 설정이 앱의 scheme과 맞는지 확인합니다.

   ```text
   discord-<APPLICATION_ID>
   craftpresence
   ```

5. `CraftPresence` scheme을 선택하고 iPhone 또는 iPad 대상에서 빌드/실행합니다.

## Discord 설정

앱은 `Info.plist`의 `APPLICATION_ID`를 읽어 Discord SDK를 설정합니다. 기본 Xcode 설정에는 `INFOPLIST_KEY_APPLICATION_ID` 빌드 설정이 연결되어 있으므로, 배포하거나 포크해서 사용할 때는 본인의 Discord 애플리케이션 ID로 바꾸는 것이 좋습니다.

Rich Presence 이미지 필드에 입력하는 `largeImageKey`, `smallImageKey`는 Discord Developer Portal에 등록된 Rich Presence asset key와 일치해야 합니다.

## 개발 메모

- 앱 설정은 `ConfigUtility` actor를 통해 JSON으로 저장됩니다.
- 기본 프리셋은 `Focus`, `Studying`, `Coding`입니다.
- `ProgramDetector`는 현재 활성 앱 정보를 내보내는 인터페이스를 갖고 있지만, 이 프로젝트의 현재 구현은 실제 감지를 수행하지 않는 스텁입니다.
- `BuildProducts/`와 DerivedData 출력물은 개발 산출물입니다. 문서나 소스 변경 시 일반적으로 수정할 필요가 없습니다.

## 테스트

Xcode에서 `CraftPresenceTests`와 `CraftPresenceUITests` 타깃을 실행할 수 있습니다.

현재 이 작업 환경은 활성 개발자 디렉터리가 Command Line Tools로 설정되어 있어 `xcodebuild` 실행 확인은 하지 않았습니다. 로컬에서 명령행 테스트를 실행하려면 Xcode가 선택되어 있는지 확인하세요.

## 라이선스

이 프로젝트는 [MIT License](LICENSE)를 따릅니다.
