# Improve iPhone page UI with Settings-style grouped cards

Labels: enhancement
GitHub: https://github.com/MinePacu/CraftPresence-iOS/issues/11

## Summary

Improve the in-app iPhone UI so each page follows a more native iOS Settings-style layout: a large top summary card, rounded grouped sections, icon-led rows, and clearer spacing for compact screens.

This issue intentionally describes the desired UI as if it has not yet been implemented, so it can be used later as the tracking issue for a branch, commit, push, and PR.

## Motivation

The current page layouts are functional, but several screens feel inconsistent on iPhone and do not match the polished grouped-card style shown in the reference. A more native settings-style layout should make navigation and editing feel clearer, especially on compact screens.

## Target Screens

- Main iPhone menu
- Overview
- Customize Presence
- Presets
- About
- Settings

## Desired Changes

- Replace plain list/page layouts with a Settings-like visual structure.
- Add a large header card per page with:
  - representative SF Symbol icon
  - page title
  - short supporting description
- Use rounded grouped sections for related controls and information.
- Use icon-led rows with chevrons for navigation-style rows.
- Keep iPad/macOS behavior stable where the existing sidebar layout is appropriate.
- Ensure compact iPhone pages remain scrollable and usable with the software keyboard visible.
- Keep text readable and avoid clipped controls on narrow screens.

## Acceptance Criteria

- iPhone compact layout shows a card-based main menu instead of a plain sidebar/list fallback.
- Each major page has consistent grouped card styling.
- Customize Presence fields remain reachable, including the bottom Party settings section.
- Settings page does not show macOS-only controls on iPhone.
- UI builds successfully for iOS.
- Manual verification is performed on an iPhone simulator or physical iPhone, including software keyboard behavior.

## Implementation Notes

A good implementation path is to introduce shared SwiftUI components for the new style, such as:

- page scroll container with grouped background
- header card
- grouped section container
- icon row
- navigation row with chevron
- section divider

Then apply those components incrementally to the target screens. Avoid large behavioral rewrites while restyling the UI.

## Follow-up Verification

After implementation, verify with:

- iPhone compact portrait
- iPhone compact landscape if supported
- iPad regular width
- software keyboard shown while editing Customize Presence fields
- Dynamic Type at least one larger size
