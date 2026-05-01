# CraftPresence

한국어 | [English](README.en.md)

CraftPresence는 Android에서 현재 사용 중인 앱과 음악 재생 정보를 Discord Rich Presence로 표시하는 앱입니다.

## 주요 기능

- Discord 계정 연결 및 Rich Presence 업데이트
- 등록한 Android 앱이 전면에 있을 때 앱 사용 상태 표시
- YouTube Music, Spotify, Apple Music 재생 정보 표시
- 곡명, 아티스트, 재생 시작/종료 시간, 앨범 아트워크 반영
- 앱별 Presence 문구, 활동 타입, 이미지 키/URL, 파티 정보 커스터마이징
- 현재 전면 앱 확인 및 알림 표시 옵션
- 한국어, 영어, 일본어 UI 텍스트 지원

## 요구 사항

- Android Studio
- JDK 11 이상
- Android SDK 36
- Android 7.0(API 24) 이상 기기
- Discord 앱 또는 Discord 로그인이 가능한 브라우저
- Discord Developer Portal에서 만든 Application ID

## 설정

`local.properties`에 Discord Application ID를 추가합니다.

```properties
DISCORD_APPLICATION_ID=123456789012345678
```

이 값은 빌드 시 Android manifest의 Discord 인증 redirect scheme에 사용됩니다. 값이 없으면 기본 placeholder인 `YOUR_APPLICATION_ID`가 들어가며, 앱에서 유효하지 않은 설정으로 표시됩니다.

## 빌드 및 테스트

```bash
./gradlew test
./gradlew assembleDebug
```

Android Studio에서는 프로젝트를 열고 `app` 구성을 실행하면 됩니다.

## 앱 권한

CraftPresence는 기능에 따라 다음 권한을 사용합니다.

- 사용 정보 접근: 현재 전면 앱을 감지하고 등록된 앱의 Presence를 갱신합니다.
- 알림 접근: 음악 앱의 현재 재생 정보를 읽습니다.
- 앱 알림: 현재 전면 앱을 Android 알림으로 표시할 때 필요합니다.
- 인터넷: Discord SDK 통신과 아트워크 조회에 사용됩니다.

권한은 앱의 `Permissions` 화면에서 상태를 확인하고 Android 설정 화면으로 이동해 허용할 수 있습니다.

## 사용 방법

1. 앱을 실행하고 Discord 계정을 연결합니다.
2. `Permissions` 화면에서 필요한 권한을 허용합니다.
3. `Programs` 화면에서 추적할 앱을 등록합니다.
4. 앱별 Presence 문구와 이미지 정보를 필요에 맞게 조정합니다.
5. `Music` 화면에서 원하는 음악 플랫폼을 시작합니다.

## 프로젝트 구조

```text
app/src/main/java/com/minepacu/craftpresence
├── core/config        # 앱 설정 저장 및 Presence 설정 모델
├── core/discord      # Discord SDK 연결 및 Activity 모델
├── core/media        # 음악 플랫폼, 미디어 세션, 아트워크 조회
├── core/permissions  # Android 권한 상태와 설정 Intent
├── core/presence     # 앱/음악 Presence 매니저
├── core/programs     # 전면 앱 감지
└── ui                # Compose UI, 테마, 다국어 텍스트
```

## 참고

- `app/libs/discord_partner_sdk.aar`는 Discord Social SDK 연동에 사용됩니다.
- `local.properties`는 개인 로컬 설정 파일이므로 Git에 포함하지 않습니다.
- 앱별 Presence 템플릿에는 `{app}`, `{package}`, `{title}` 값을 사용할 수 있습니다.
