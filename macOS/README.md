# CraftPresence

> [**English**](README_EN.md) | **한국어**

macOS에서 실행 중인 애플리케이션을 실시간으로 추적하고, Discord Rich Presence를 통해 현재 활동을 자동으로 업데이트하는 애플리케이션입니다.

![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%2026.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## 목차
- [소개](#소개)
- [주요 기능](#주요-기능)
- [스크린샷](#스크린샷)
- [요구 사항](#요구-사항)
- [설치 및 빌드](#설치-및-빌드)
- [설정](#설정)
- [사용 방법](#사용-방법)
- [프로젝트 구조](#프로젝트-구조)
- [기술 스택](#기술-스택)
- [문제 해결](#문제-해결)
- [기여](#기여)
- [라이선스](#라이선스)

## 소개

CraftPresence는 macOS 사용자를 위한 Discord Rich Presence 관리 도구입니다. 현재 실행 중인 애플리케이션을 자동으로 감지하고, Discord 프로필에 표시되는 활동 상태를 실시간으로 업데이트합니다.

### 왜 CraftPresence인가?

- **🎮 자동 감지**: 수동 설정 없이 실행 중인 애플리케이션을 자동으로 추적
- **⚙️ 커스터마이징**: 프로그램별로 Rich Presence 표시 내용을 세밀하게 조정
- **🔒 프라이버시**: 원하는 애플리케이션만 선택적으로 추적
- **🎨 SwiftUI**: 최신 SwiftUI와 Swift 6.0을 활용한 네이티브 macOS 앱

## 주요 기능

### 1. 실시간 애플리케이션 추적
- macOS Accessibility API를 활용한 포그라운드 애플리케이션 감지
- 애플리케이션 이름, Bundle ID, 창 타이틀 자동 인식
- 실시간 업데이트로 애플리케이션 전환 즉시 반영

### 2. Discord Rich Presence 통합
- Discord C++ SDK를 활용한 네이티브 통합
- Swift/C++ Interoperability를 통한 안정적인 연동
- OAuth2 인증 지원
- 사용자 정보 자동 조회

### 3. 프로그램별 커스터마이징
- 각 애플리케이션별 Rich Presence 설정 저장
- State, Details, 이미지 등 세부 설정 가능
- JSON 기반 설정 파일로 데이터 영속성 보장

### 4. 사용자 친화적 인터페이스
- SwiftUI 기반 모던한 UI
- 사이드바 네비게이션으로 직관적인 화면 전환
- 프로그램 목록 관리 및 설정 화면
- 디버그/테스트 화면 내장



### 시스템 요구 사항
- **macOS**: 26.0 (Sequoia) 이상
- **Xcode**: 26.0.1 이상
- **Swift**: 6.0 이상

### Discord 설정
- Discord 계정
- Discord Developer Portal에서 생성한 Application ID
- Rich Presence 기능이 활성화된 Discord 애플리케이션

## 설치 및 빌드

### 1. 저장소 클론

```bash
git clone https://github.com/MinePacu/CraftPresence.git
cd CraftPresence
```

### 2. Discord SDK 라이브러리 확인

프로젝트에는 Discord Partner SDK가 포함되어 있습니다:
```
CraftPresence/ThirdParty/DIscordSDK/
├── include/
│   ├── discordpp.h
│   ├── DiscordppWrapper.hpp
│   └── DiscordppWrapper.cpp
└── lib/
    └── libdiscord_partner_sdk.dylib
```

### 3. Xcode에서 프로젝트 열기

```bash
open CraftPresence.xcodeproj
```

### 4. 프로젝트 빌드

1. Xcode에서 타겟을 `CraftPresence`로 선택
2. `Product > Build` (⌘+B) 실행
3. 빌드가 성공하면 `Product > Run` (⌘+R)으로 실행

## 설정

### Discord Application ID 설정

#### 방법 1: Info.plist 편집
1. Discord Developer Portal에서 Application 생성
2. Application ID 복사
3. `CraftPresence/Info.plist` 파일에서 `APPLICATION_ID` 키 값 변경

```xml
<key>APPLICATION_ID</key>
<string>YOUR_DISCORD_APPLICATION_ID</string>
```

#### 방법 2: 환경 변수 사용
```bash
export APPLICATION_ID="YOUR_DISCORD_APPLICATION_ID"
```

### Accessibility 권한 허용

앱이 실행 중인 애플리케이션을 감지하려면 Accessibility 권한이 필요합니다:

1. 앱 최초 실행 시 권한 요청 화면 표시
2. `시스템 설정 > 개인 정보 보호 및 보안 > 손쉬운 사용` 이동
3. CraftPresence 앱 활성화
4. 앱 재시작

## 사용 방법

### 1. 앱 실행 및 인증
1. CraftPresence 실행
2. Discord 로그인 (OAuth2 인증)
3. 권한 승인

### 2. 프로그램 추가
1. 사이드바에서 "Programs" 선택
2. 추적할 애플리케이션 실행
3. 자동으로 감지되거나 수동으로 Bundle ID 입력

### 3. Rich Presence 커스터마이징
1. 프로그램 목록에서 원하는 앱 선택
2. State, Details, 이미지 등 설정
3. 변경사항 자동 저장

### 4. 실시간 모니터링
- Overview 화면에서 현재 포그라운드 앱 확인
- Discord 프로필에 실시간 반영 확인

## 프로젝트 구조

```
CraftPresence/
├── CraftPresence/
│   ├── CraftPresenceApp.swift      # 앱 진입점
│   ├── ContentView.swift           # 메인 UI
│   ├── PermissionView.swift        # 권한 요청 UI
│   ├── Item.swift                  # 데이터 모델
│   ├── Core/
│   │   ├── DiscordSDK.swift        # Discord SDK 매니저
│   │   ├── ProgramDetector.swift   # 애플리케이션 감지
│   │   ├── ConfigUtility.swift     # 설정 관리
│   │   └── PermissionService.swift # 권한 관리
│   ├── ThirdParty/
│   │   └── DIscordSDK/             # Discord C++ SDK
│   │       ├── include/
│   │       │   ├── discordpp.h
│   │       │   ├── DiscordppWrapper.hpp
│   │       │   └── DiscordppWrapper.cpp
│   │       ├── lib/
│   │       │   └── libdiscord_partner_sdk.dylib
│   │       └── modules/
│   │           └── module.modulemap
│   └── Assets.xcassets/
└── CraftPresenceTests/
```

## 기술 스택

### 언어 및 프레임워크
- **Swift 6.0**: 최신 Swift 동시성 기능 활용
- **SwiftUI**: 선언적 UI 프레임워크
- **SwiftData**: 데이터 영속성
- **C++20**: Discord SDK 연동

### 주요 라이브러리
- **Discord Partner SDK**: C++ 네이티브 SDK
- **Swift/C++ Interoperability**: Swift-C++ 브릿지
- **macOS Accessibility API**: 애플리케이션 감지

### 아키텍처 패턴
- **MVVM**: Model-View-ViewModel
- **Actor 모델**: Thread-safe 상태 관리
- **Async/Await**: 비동기 작업 처리

## 문제 해결

### Accessibility 권한 문제
**증상**: 애플리케이션 감지가 작동하지 않음

**해결책**:
1. 시스템 설정에서 Accessibility 권한 확인
2. 앱 재시작
3. 필요시 권한 제거 후 재부여

### Discord 연결 실패
**증상**: Discord Rich Presence 업데이트 안됨

**해결책**:
1. Discord 앱이 실행 중인지 확인
2. Application ID가 올바른지 확인
3. Discord Developer Portal에서 앱 활성화 상태 확인
4. 로그 확인: Debug > Discord Test 화면

### 빌드 오류
**증상**: Linker 에러 또는 모듈 찾을 수 없음

**해결책**:
1. Clean Build Folder (⌘+Shift+K)
2. Derived Data 삭제
3. Xcode 재시작
4. 프로젝트 설정 확인:
   - Header Search Paths
   - Library Search Paths
   - Other Linker Flags

## 기여

기여를 환영합니다! 다음 절차를 따라주세요:

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### 개발 가이드라인
- Swift 코드 스타일 가이드 준수
- 새로운 기능에 대한 테스트 작성
- 문서 업데이트
- Commit 메시지는 명확하고 간결하게

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 문의

프로젝트 관련 문의사항이나 버그 리포트는 GitHub Issues를 이용해주세요.

- **GitHub**: [MinePacu/CraftPresence](https://github.com/MinePacu/CraftPresence)
- **Issues**: [버그 리포트 및 기능 제안](https://github.com/MinePacu/CraftPresence/issues)

---

**Made by MinePacu**
