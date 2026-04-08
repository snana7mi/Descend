# Asset Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enrich `Descend`'s presentation by integrating free art packs into backgrounds, overlays, and platform visuals without changing gameplay behavior.

**Architecture:** Keep gameplay logic intact and add a thin presentation layer on top of the existing SpriteKit scene. Introduce one focused background system, extend theme definitions with asset skin identifiers, and route UI/platform visuals through reusable skin-aware factories so dark and light themes can swap resources consistently.

**Tech Stack:** Swift, SpriteKit, Xcode asset catalogs, `xcodebuild`

---

## Asset Manifest

Use exactly these free source packs for the first pass. All Kenney asset pages are `CC0` / public domain according to [Kenney support](https://kenney.nl/support).

**Source packs**
- Dark-theme background accents: [Kenney Background Elements](https://kenney.nl/assets/background-elements)
- Dark-theme UI chrome: [Kenney UI Pack - Sci-Fi](https://kenney.nl/assets/ui-pack-sci-fi)
- Light-theme UI chrome: [Kenney UI Pack](https://kenney.nl/assets/ui-pack)
- Platform surface details: [Kenney Platformer Pack Industrial](https://kenney.nl/assets/platformer-pack-industrial)

**Exact in-repo asset outputs**
- `Descend/Assets.xcassets/Backgrounds/Dark/bg_dark_base.imageset/bg_dark_base.png`
- `Descend/Assets.xcassets/Backgrounds/Dark/bg_dark_mid.imageset/bg_dark_mid.png`
- `Descend/Assets.xcassets/Backgrounds/Dark/bg_dark_accent.imageset/bg_dark_accent.png`
- `Descend/Assets.xcassets/Backgrounds/Light/bg_light_base.imageset/bg_light_base.png`
- `Descend/Assets.xcassets/Backgrounds/Light/bg_light_mid.imageset/bg_light_mid.png`
- `Descend/Assets.xcassets/Backgrounds/Light/bg_light_accent.imageset/bg_light_accent.png`
- `Descend/Assets.xcassets/UI/Dark/ui_dark_panel.imageset/ui_dark_panel.png`
- `Descend/Assets.xcassets/UI/Dark/ui_dark_badge.imageset/ui_dark_badge.png`
- `Descend/Assets.xcassets/UI/Dark/ui_dark_hint.imageset/ui_dark_hint.png`
- `Descend/Assets.xcassets/UI/Light/ui_light_panel.imageset/ui_light_panel.png`
- `Descend/Assets.xcassets/UI/Light/ui_light_badge.imageset/ui_light_badge.png`
- `Descend/Assets.xcassets/UI/Light/ui_light_hint.imageset/ui_light_hint.png`
- `Descend/Assets.xcassets/Platforms/Dark/platform_dark_normal.imageset/platform_dark_normal.png`
- `Descend/Assets.xcassets/Platforms/Dark/platform_dark_special.imageset/platform_dark_special.png`
- `Descend/Assets.xcassets/Platforms/Light/platform_light_normal.imageset/platform_light_normal.png`
- `Descend/Assets.xcassets/Platforms/Light/platform_light_special.imageset/platform_light_special.png`

**Selection rules for those outputs**
- `bg_dark_base.png`: export one wide, low-contrast abstract background piece from `Background Elements`; use the least busy shape set so danger zones and platforms stay readable.
- `bg_dark_mid.png`: export a second darker geometric layer from `Background Elements` with medium visual density.
- `bg_dark_accent.png`: export a brighter accent layer from `Background Elements` that can be tinted toward cyan/magenta and moved fastest.
- `bg_light_base.png`: derive from the current pastel gradient look. Use either a very soft background element from `Background Elements` recolored to the light theme palette or a custom flattened pastel gradient image created from the existing light theme colors.
- `bg_light_mid.png`: export or derive a soft cloud/blob/geometric mid layer for the light theme.
- `bg_light_accent.png`: export or derive a sparse sparkle/blob accent layer for the light theme.
- `ui_dark_panel.png`: choose one large rectangular sci-fi panel frame from `UI Pack - Sci-Fi`.
- `ui_dark_badge.png`: choose one compact sci-fi status panel or counter frame from `UI Pack - Sci-Fi`.
- `ui_dark_hint.png`: choose one wide sci-fi button frame from `UI Pack - Sci-Fi`.
- `ui_light_panel.png`: choose one rounded bright panel frame from `UI Pack`.
- `ui_light_badge.png`: choose one rounded score/counter frame from `UI Pack`.
- `ui_light_hint.png`: choose one wide rounded button frame from `UI Pack`.
- `platform_dark_normal.png`: export one straight industrial platform top/surface tile from `Platformer Pack Industrial`.
- `platform_dark_special.png`: export a second industrial tile with stronger trim/highlight for special platforms.
- `platform_light_normal.png`: reuse the same industrial base tile but recolor it into the pastel theme and flatten it to a clean PNG.
- `platform_light_special.png`: reuse the special industrial tile, recolored for the light theme.

**Non-negotiable constraints**
- Use exactly one image per output above in the first pass. Do not leave image choice open-ended during implementation.
- If a source pack has multiple close variants, pick the simplest frame/tile that preserves readability after scaling to phone screens.
- Resize or crop during import if needed, but keep the output filenames above unchanged so the code can hardcode them.

---

## File Structure

**Create**
- `Descend/Systems/BackgroundSystem.swift` — owns parallax background layers, looping logic, theme skin loading, and update hooks
- `Descend/Assets.xcassets/Backgrounds/Contents.json` — asset group root for background textures
- `Descend/Assets.xcassets/Backgrounds/Dark/Contents.json` — dark-theme background namespace
- `Descend/Assets.xcassets/Backgrounds/Light/Contents.json` — light-theme background namespace
- `Descend/Assets.xcassets/UI/Contents.json` — asset group root for UI textures
- `Descend/Assets.xcassets/UI/Dark/Contents.json` — dark-theme UI namespace
- `Descend/Assets.xcassets/UI/Light/Contents.json` — light-theme UI namespace
- `Descend/Assets.xcassets/Platforms/Contents.json` — asset group root for platform textures
- `Descend/Assets.xcassets/Platforms/Dark/Contents.json` — dark-theme platform namespace
- `Descend/Assets.xcassets/Platforms/Light/Contents.json` — light-theme platform namespace

**Modify**
- `Descend/Scenes/GameScene.swift` — instantiate/update background system and refresh visual skins on theme change
- `Descend/Theme/ThemeDefinition.swift` — add asset skin identifiers for background/UI/platform visuals
- `Descend/Theme/DarkTheme.swift` — bind dark theme to dark asset sets
- `Descend/Theme/LightTheme.swift` — bind light theme to light asset sets
- `Descend/UI/UIFactory.swift` — add skin-aware panel/badge/button-hint builders backed by textures with shape fallback
- `Descend/UI/StartOverlay.swift` — replace bare panel presentation with skinned UI composition
- `Descend/UI/GameOverOverlay.swift` — replace bare panel presentation with skinned UI composition
- `Descend/Nodes/PlatformNode.swift` — add surface ornament sprite layer while preserving collision body and sizing
- `Descend/Systems/PlatformSystem.swift` — ensure recycled platforms reapply skins after reuse/theme changes
- `Descend/Systems/VisualEffects.swift` — optionally reuse accent assets for overlay decoration if needed

**Verify**
- Build command: `xcodebuild -project Descend.xcodeproj -scheme Descend -sdk iphonesimulator -configuration Debug build`

---

### Task 1: Prepare Asset Catalog Layout

**Files:**
- Create: `Descend/Assets.xcassets/Backgrounds/Contents.json`
- Create: `Descend/Assets.xcassets/Backgrounds/Dark/Contents.json`
- Create: `Descend/Assets.xcassets/Backgrounds/Light/Contents.json`
- Create: `Descend/Assets.xcassets/UI/Contents.json`
- Create: `Descend/Assets.xcassets/UI/Dark/Contents.json`
- Create: `Descend/Assets.xcassets/UI/Light/Contents.json`
- Create: `Descend/Assets.xcassets/Platforms/Contents.json`
- Create: `Descend/Assets.xcassets/Platforms/Dark/Contents.json`
- Create: `Descend/Assets.xcassets/Platforms/Light/Contents.json`

- [ ] **Step 1: Create the asset namespace folders and placeholder `Contents.json` files**

Use the same catalog structure style as existing entries under `Descend/Assets.xcassets`.

- [ ] **Step 2: Download the four source packs and import the exact first-pass files**

Download only these packs:
- `Kenney Background Elements`
- `Kenney UI Pack - Sci-Fi`
- `Kenney UI Pack`
- `Kenney Platformer Pack Industrial`

Create these exact image sets and place one PNG in each:
- `Descend/Assets.xcassets/Backgrounds/Dark/bg_dark_base.imageset/bg_dark_base.png`
- `Descend/Assets.xcassets/Backgrounds/Dark/bg_dark_mid.imageset/bg_dark_mid.png`
- `Descend/Assets.xcassets/Backgrounds/Dark/bg_dark_accent.imageset/bg_dark_accent.png`
- `Descend/Assets.xcassets/Backgrounds/Light/bg_light_base.imageset/bg_light_base.png`
- `Descend/Assets.xcassets/Backgrounds/Light/bg_light_mid.imageset/bg_light_mid.png`
- `Descend/Assets.xcassets/Backgrounds/Light/bg_light_accent.imageset/bg_light_accent.png`
- `Descend/Assets.xcassets/UI/Dark/ui_dark_panel.imageset/ui_dark_panel.png`
- `Descend/Assets.xcassets/UI/Dark/ui_dark_badge.imageset/ui_dark_badge.png`
- `Descend/Assets.xcassets/UI/Dark/ui_dark_hint.imageset/ui_dark_hint.png`
- `Descend/Assets.xcassets/UI/Light/ui_light_panel.imageset/ui_light_panel.png`
- `Descend/Assets.xcassets/UI/Light/ui_light_badge.imageset/ui_light_badge.png`
- `Descend/Assets.xcassets/UI/Light/ui_light_hint.imageset/ui_light_hint.png`
- `Descend/Assets.xcassets/Platforms/Dark/platform_dark_normal.imageset/platform_dark_normal.png`
- `Descend/Assets.xcassets/Platforms/Dark/platform_dark_special.imageset/platform_dark_special.png`
- `Descend/Assets.xcassets/Platforms/Light/platform_light_normal.imageset/platform_light_normal.png`
- `Descend/Assets.xcassets/Platforms/Light/platform_light_special.imageset/platform_light_special.png`

Map each output to the source pack using the `Asset Manifest` section above. Do not substitute additional packs in the first pass.

- [ ] **Step 3: Create `Contents.json` for every `.imageset` and document the source-to-output mapping**

Write a short note in the plan execution log or commit message body listing:
- source pack name
- chosen source art description
- output filename in the repo

The code should reference only the final output names:
- Dark backgrounds: `bg_dark_base`, `bg_dark_mid`, `bg_dark_accent`
- Light backgrounds: `bg_light_base`, `bg_light_mid`, `bg_light_accent`
- Dark UI: `ui_dark_panel`, `ui_dark_badge`, `ui_dark_hint`
- Light UI: `ui_light_panel`, `ui_light_badge`, `ui_light_hint`
- Dark platforms: `platform_dark_normal`, `platform_dark_special`
- Light platforms: `platform_light_normal`, `platform_light_special`

- [ ] **Step 4: Build to catch catalog or target membership issues**

Run: `xcodebuild -project Descend.xcodeproj -scheme Descend -sdk iphonesimulator -configuration Debug build`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Descend/Assets.xcassets docs/superpowers/plans/2026-04-08-asset-integration-plan.md
git commit -m "chore: scaffold asset catalog structure for visual skins"
```

### Task 2: Extend Theme Models With Asset Skin Keys

**Files:**
- Modify: `Descend/Theme/ThemeDefinition.swift`
- Modify: `Descend/Theme/DarkTheme.swift`
- Modify: `Descend/Theme/LightTheme.swift`

- [ ] **Step 1: Add asset-skin fields to the theme definition**

Introduce fields for:
- `backgroundSkin`
- `uiSkin`
- `platformSkin`

Keep these as lightweight string-backed identifiers or small enums so theme switching stays simple.

- [ ] **Step 2: Set dark and light theme values**

Dark theme should point to dark asset sets; light theme should point to light asset sets.

- [ ] **Step 3: Update any call sites broken by the new theme definition**

Search: `rg "Theme\\(" Descend/Theme Descend/Scenes Descend/UI Descend/Nodes`

Expected: every theme initialization compiles with the new fields populated.

- [ ] **Step 4: Build to verify theme changes compile**

Run: `xcodebuild -project Descend.xcodeproj -scheme Descend -sdk iphonesimulator -configuration Debug build`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Descend/Theme/ThemeDefinition.swift Descend/Theme/DarkTheme.swift Descend/Theme/LightTheme.swift
git commit -m "feat: add asset skin identifiers to themes"
```

### Task 3: Add a Reusable Background System

**Files:**
- Create: `Descend/Systems/BackgroundSystem.swift`
- Modify: `Descend/Scenes/GameScene.swift`

- [ ] **Step 1: Write a focused system interface**

Define a small API similar to:

```swift
final class BackgroundSystem {
    init(scene: SKScene)
    func applyTheme(_ theme: Theme)
    func update(delta: TimeInterval, riseSpeed: CGFloat)
    func reset()
}
```

- [ ] **Step 2: Implement looping parallax layers**

Use 2 sprites per layer for seamless vertical wrap. Maintain three layers:
- base: slowest movement
- mid: medium movement
- accent: fastest subtle movement

Fallback to gradient/color nodes if a texture is missing so the game still runs.

- [ ] **Step 3: Integrate the system into `GameScene`**

In `didMove(to:)`:
- instantiate `BackgroundSystem`
- apply current theme after `setupBackground(theme:)`

In `update(_:)`:
- update the background system using the effective rise speed

In restart/theme-change flows:
- reset or reapply skins so loops don't duplicate

- [ ] **Step 4: Build and manually verify parallax behavior**

Run build:
`xcodebuild -project Descend.xcodeproj -scheme Descend -sdk iphonesimulator -configuration Debug build`

Manual check in simulator:
- start a run in dark mode and confirm 3 visible depth layers
- switch system appearance and confirm all layers refresh
- restart after game over and confirm no duplicate background nodes remain

- [ ] **Step 5: Commit**

```bash
git add Descend/Systems/BackgroundSystem.swift Descend/Scenes/GameScene.swift
git commit -m "feat: add theme-aware parallax background system"
```

### Task 4: Skin Overlay Panels Through `UIFactory`

**Files:**
- Modify: `Descend/UI/UIFactory.swift`
- Modify: `Descend/UI/StartOverlay.swift`
- Modify: `Descend/UI/GameOverOverlay.swift`

- [ ] **Step 1: Add textured UI builders with fallback behavior**

Extend `UIFactory` with builders such as:

```swift
static func makeSkinnedPanel(theme: Theme, size: CGSize) -> SKNode
static func makeSkinnedBadge(theme: Theme, size: CGSize) -> SKNode
static func makeHintButton(theme: Theme, text: String, size: CGSize) -> SKNode
```

Each builder should:
- load a texture matching the active `uiSkin`
- size it to the requested bounds
- fall back to existing `SKShapeNode` styling if the texture is unavailable

- [ ] **Step 2: Update `StartOverlay` composition**

Replace the plain panel with a skinned panel, keep `Descend` as text, and anchor the start hint inside a hint-button container.

- [ ] **Step 3: Update `GameOverOverlay` composition**

Wrap score text in a badge frame and present restart hint inside the same hint-button style used by the start screen.

- [ ] **Step 4: Build and manually verify theme consistency**

Run build:
`xcodebuild -project Descend.xcodeproj -scheme Descend -sdk iphonesimulator -configuration Debug build`

Manual check:
- waiting-to-start overlay looks themed in dark mode
- game-over overlay looks themed in light mode
- localized strings still fit inside the skinned containers

- [ ] **Step 5: Commit**

```bash
git add Descend/UI/UIFactory.swift Descend/UI/StartOverlay.swift Descend/UI/GameOverOverlay.swift
git commit -m "feat: skin start and game-over overlays with themed assets"
```

### Task 5: Add Platform Surface Skins Without Changing Gameplay

**Files:**
- Modify: `Descend/Nodes/PlatformNode.swift`
- Modify: `Descend/Systems/PlatformSystem.swift`

- [ ] **Step 1: Add a decorative sprite layer to `PlatformNode`**

Create one child sprite for the platform surface and optionally one ornament/highlight child. Keep physics body generation unchanged.

- [ ] **Step 2: Add a skin application method**

Expose a method such as:

```swift
func applySkin(theme: Theme, platformType: PlatformType)
```

This method should:
- pick texture(s) based on `platformSkin` and platform type
- preserve existing sizing rules
- tint or blend where needed so special platform readability remains intact

- [ ] **Step 3: Reapply skins when platforms are spawned, reused, or theme changes**

Update `PlatformSystem` so pooled nodes always refresh their decorative sprites after configuration.

- [ ] **Step 4: Build and manually verify gameplay parity**

Run build:
`xcodebuild -project Descend.xcodeproj -scheme Descend -sdk iphonesimulator -configuration Debug build`

Manual check:
- platform collision timing feels unchanged
- special platform types remain visually distinguishable
- recycled platforms do not keep stale textures from previous themes/types

- [ ] **Step 5: Commit**

```bash
git add Descend/Nodes/PlatformNode.swift Descend/Systems/PlatformSystem.swift
git commit -m "feat: add themed decorative skins to platforms"
```

### Task 6: Final Polish and Regression Verification

**Files:**
- Modify: `Descend/Scenes/GameScene.swift`
- Modify: `Descend/Systems/VisualEffects.swift`
- Modify: any touched file needed for cleanup

- [ ] **Step 1: Remove dead styling code only where the new skin system fully replaces it**

Keep fallbacks in place; do not remove shape-based rendering that still protects against missing assets.

- [ ] **Step 2: Verify z-order and readability**

Check that:
- backgrounds stay behind danger zones and gameplay
- overlays stay above gameplay/effects
- labels remain readable against textured panels

- [ ] **Step 3: Run a full debug build**

Run:
`xcodebuild -project Descend.xcodeproj -scheme Descend -sdk iphonesimulator -configuration Debug build`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Perform a visual smoke test**

Manual pass:
- launch in dark mode
- play until game over
- restart
- switch to light mode
- play again
- confirm BGM/theme switching still works and visual assets update with no missing textures

- [ ] **Step 5: Commit**

```bash
git add Descend/Scenes/GameScene.swift Descend/Systems/VisualEffects.swift Descend/Nodes/PlatformNode.swift Descend/Systems/PlatformSystem.swift Descend/UI/UIFactory.swift Descend/UI/StartOverlay.swift Descend/UI/GameOverOverlay.swift Descend/Theme/ThemeDefinition.swift Descend/Theme/DarkTheme.swift Descend/Theme/LightTheme.swift Descend/Systems/BackgroundSystem.swift
git commit -m "feat: integrate themed background and UI asset skins"
```
