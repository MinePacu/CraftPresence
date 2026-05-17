# Android Care Hub Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement GitHub issue #76 by turning the Android home screen into a CraftPresence Care Hub and enforcing Tracked Apps edit locking when foreground detection is disabled.

**Architecture:** Add a small testable state-mapping layer for Care Hub status, tile state, permission summary, and Tracked Apps lock behavior. Reuse the existing Compose navigation and settings-panel structure while restyling Overview, Programs, and Permissions around shared Care Hub/detail components.

**Tech Stack:** Kotlin, Android Jetpack Compose, Material 3, JUnit 4, Gradle.

---

### Task 1: Care Hub State Model

**Files:**
- Create: `app/src/main/java/com/minepacu/craftpresence/ui/care/CareHubModels.kt`
- Test: `app/src/test/java/com/minepacu/craftpresence/CareHubModelsTest.kt`

- [ ] **Step 1:** Write tests for home health priority, permission summary, and Tracked Apps lock state.
- [ ] **Step 2:** Run `./gradlew :app:testDebugUnitTest --tests com.minepacu.craftpresence.CareHubModelsTest --rerun-tasks` and verify the missing model failure.
- [ ] **Step 3:** Implement `CareHubModels.kt`.
- [ ] **Step 4:** Run the focused test again and verify it passes.

### Task 2: Compose Care Hub Components

**Files:**
- Modify: `app/src/main/java/com/minepacu/craftpresence/CommonUi.kt`
- Modify: `app/src/main/java/com/minepacu/craftpresence/MainActivity.kt`

- [ ] **Step 1:** Add reusable UI components for status header, status tile, grouped action section, detail header, and locked rows.
- [ ] **Step 2:** Replace `OverviewScreen` with the Care Hub layout using four primary tiles: Discord, Presence, Tracked Apps, Permissions.
- [ ] **Step 3:** Run `./gradlew :app:testDebugUnitTest`.

### Task 3: Tracked Apps Detail Locking

**Files:**
- Modify: `app/src/main/java/com/minepacu/craftpresence/MainActivity.kt`
- Modify: `app/src/main/java/com/minepacu/craftpresence/ui/localization/LocalizedText.kt`

- [ ] **Step 1:** Use `resolveTrackedAppsState` in Programs settings.
- [ ] **Step 2:** Disable current app add and registered app edit actions when foreground detection is off.
- [ ] **Step 3:** Show localized helper text explaining that foreground detection must be enabled first.
- [ ] **Step 4:** Run `./gradlew :app:testDebugUnitTest`.

### Task 4: Permissions Detail Refresh

**Files:**
- Modify: `app/src/main/java/com/minepacu/craftpresence/MainActivity.kt`

- [ ] **Step 1:** Restyle `PermissionsScreen` around the detail template.
- [ ] **Step 2:** Use real permission completion state only for checklist/progress semantics.
- [ ] **Step 3:** Run `./gradlew :app:testDebugUnitTest`.

### Task 5: Final Verification

**Files:**
- Verify changed Android files.

- [ ] **Step 1:** Run `./gradlew :app:testDebugUnitTest`.
- [ ] **Step 2:** Run `./gradlew :app:assembleDebug`.
- [ ] **Step 3:** Run `git diff --stat` and inspect `git diff`.
