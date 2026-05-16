# Android Care Hub Redesign Design

## Summary

Redesign the Android app UI around a CraftPresence-specific "Care Hub" direction. The first reference image is used only for broad layout ideas: a clear health state, compact status tiles, and grouped management rows. The UI must not closely copy Samsung Device Care wording, metrics, iconography, or visual identity.

The approved direction is "CraftPresence Care Hub": keep the screen focused on Discord Presence setup and management, not generic device maintenance.

## Goals

- Make the Android app feel more direct and status-oriented.
- Show the current CraftPresence health at a glance.
- Let users enter each domain, such as Discord, Presence, Tracked Apps, Permissions, Music, and Backup, through predictable rows.
- Use the second reference image only as a pattern for detail screen hierarchy: back/title, state summary, grouped controls, lists, and help.
- Avoid fake metrics, usage percentages, or progress bars where they do not represent real completion or capacity.
- Follow Android system dark mode and light mode automatically.

## Non-Goals

- Do not clone Samsung Device Care UI exactly.
- Do not show battery, storage, memory, app usage percentages, or device-care labels unless they directly map to CraftPresence behavior.
- Do not add an in-app theme toggle in this redesign.
- Do not change Discord, foreground detection, permission, or music business logic beyond enabling and disabling UI actions based on existing state.

## Home Screen

The home screen becomes the main CraftPresence Care Hub.

Top section:

- App title remains CraftPresence.
- Center status uses CraftPresence-specific visual language, such as a status mark or presence-oriented icon, instead of copying the green face from the reference.
- Primary state text should use simple Korean states such as "좋아요", "설정 필요", or "연결 안 됨".
- Supporting text explains the concrete app state, for example Discord connected, permissions needed, or Presence ready.
- Primary button triggers the next best action, such as opening permissions, connecting Discord, or editing Presence.

Status tiles:

- Use a compact 2-column grid.
- Use four primary tiles:
  - Discord
  - Presence
  - Tracked Apps
  - Permissions
- Music remains a management row by default. It may replace another tile only if a future product decision makes music the active primary mode.
- Each tile shows a short label and concrete status, such as Ready, 앱 우선, 3개 추적 중, 1개 필요, 대기 중.
- Do not use progress bars unless the tile has real checklist or capacity meaning.

Grouped rows:

- "빠른 작업" should contain high-frequency tasks:
  - Presence 편집
  - 추적 앱 관리
  - 권한 점검
- "관리" should contain setup and secondary destinations:
  - Discord 계정
  - Music Presence
  - 백업 및 복원
- Rows should be tappable, use icons where helpful, and show a chevron or clear affordance.

## Detail Screen Template

Each hub item opens a detail screen based on a shared structure.

Top:

- Back button.
- Detail title.
- Large state summary.
- Short explanatory subtitle.
- State chips for key state facts.

Body:

- Group controls in rounded cards.
- Use switches for binary runtime settings.
- Use buttons for actions such as opening Android Settings, adding the current app, reconnecting Discord, or starting music monitoring.
- Use list rows for editable entities.
- Use helper rows or help cards at the bottom for explanation.

Progress and bars:

- Use progress only when it maps to real completion, such as Permissions 2 of 3.
- Prefer state chips for runtime status.
- Prefer list rows for entities such as registered apps.

## Tracked Apps Detail

Tracked Apps is an entity management screen, not a usage analytics screen.

State summary:

- Show text such as "3개 앱 추적 중" when foreground detection is active.
- Show text such as "Foreground 감지 꺼짐" when foreground detection is inactive.
- Use state chips such as "감지 실행 중", "앱 Presence 우선", "감지 비활성화", or "편집 잠김".
- Do not show app usage percentages.
- Do not show a green progress bar in Tracked Apps.

Controls:

- Foreground detection switch remains available at all times.
- "현재 앱 추가" depends on foreground detection.
- Registered app editing depends on foreground detection.
- App-specific Presence preset editing depends on foreground detection.

Disabled state:

- If foreground detection is off, disable "현재 앱 추가".
- If foreground detection is off, disable registered app rows and prevent navigation to edit screens.
- If foreground detection is off, disable Presence preset edit entry points.
- Show in-place helper text such as "감지를 켠 뒤 사용할 수 있습니다".
- The disabled state must be enforced in click handlers, not only by visual opacity.

Registered app rows:

- Show app icon or fallback initial.
- Show app name.
- Show package name or preset status, such as "기본 프리셋", "사용자 지정 프리셋", or "음악 Presence 프리셋".
- Show edit/navigation affordance only when enabled.

## Permissions Detail

Permissions can use checklist-style progress because the app has a real finite set of permission requirements.

State summary:

- Show the number of missing permissions, for example "1개 권한 필요".
- Use chips for each major permission state.
- A compact completion indicator may be used if it clearly represents required permission completion.

Rows:

- Usage Access.
- App notification permission.
- Notification Listener.

Actions:

- Granted permissions show completed state.
- Missing permissions show a primary action to open the appropriate Android Settings screen or request permission.
- Include a short return hint after Android Settings handoff.

## Discord, Presence, Music, And Backup Details

Discord:

- Show connection state, current user, Application ID status, reconnect/disconnect actions, and last error if present.
- Avoid large fake graphs or unrelated health metrics.

Presence:

- Keep Presence preview prominent.
- Show current source priority and selected app/preset state.
- Group editable fields under focused sections.

Music:

- Show active platform, current track if present, monitoring state, and platform rows.
- Use artwork only when real artwork exists.
- Use start/stop controls instead of progress bars.

Backup:

- Show export/import actions and last known backup state if available.
- Keep this as a management detail, not a device repair metaphor.

## Theme Behavior

The redesigned UI follows Android system dark mode and light mode.

- Keep using the existing `CraftPresenceTheme` behavior based on `isSystemInDarkTheme()`.
- Do not add an in-app dark/light override in this scope.
- Implement new colors through `MaterialTheme.colorScheme` so light and dark modes both work.
- The dark mockups define the approved hierarchy and density, not the only color mode.
- In dark mode, use a black or near-black app background with dark grouped surfaces.
- In light mode, use the existing light background and surface palette with the same layout and hierarchy.

## Components

Add or adapt reusable Compose components:

- Care hub status header.
- Compact status tile.
- Grouped action section.
- Detail screen header.
- State chip row.
- Locked row treatment for disabled dependent actions.

Existing shared components such as `InfoCard`, `StatusChip`, `AppIconImage`, and `SetupHealthCard` can be reused or restyled where they still fit the new hierarchy.

## Data And State Rules

- Home state is derived from existing settings, Discord state, foreground detection state, permission state, program presence state, and music state.
- Detail screens should not introduce synthetic analytics.
- Disabled UI rules must use the same source of truth as the feature logic.
- If foreground detection is disabled, dependent Tracked Apps actions must be disabled consistently.

## Navigation

The implementation can keep the existing Compose tab architecture initially, but the Overview/Home tab should visually become the Care Hub.

Settings subpages can be reused as destination screens where appropriate. If a full navigation refactor is needed later, it should be separate from this redesign.

## Testing

Minimum verification:

- Build compiles.
- Existing unit tests pass.
- Home renders in dark and light mode.
- Tracked Apps disabled state blocks current app add and registered app edit navigation when foreground detection is off.
- Tracked Apps enabled state restores those actions when foreground detection is on.
- Permissions detail correctly reflects granted and missing permissions.
- Text does not overflow on narrow Android widths.

## Open Implementation Notes

- Korean localization keys should be added or updated for new labels.
- English and Japanese strings should remain coherent if the app supports them in the same files.
- The visual design should be distinct enough from Samsung Device Care by using CraftPresence-specific names, icons, states, and information structure.
