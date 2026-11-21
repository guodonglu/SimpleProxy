# WhistFlow - Agent Context & Memory Log

This document is maintained continuously across turns to preserve context, architecture decisions, and task execution progress.

## 1. Project Overview & Requirements
- **Product Name**: WhistFlow
- **Type**: Native macOS Proxy Application (Swift / SwiftUI / Network.framework)
- **Design Target**: macOS 26/27 Human Interface Guidelines (Liquid Glass vibrancy, squircle radius, single accent color, semantic labels, integrated title bar with 78pt traffic light offset).
- **Core Functionality**:
  - Focus exclusively on proxy & rule routing (Host/IP mapping, Map Remote, Map Local/Mock, Header rewrite, Status rewrite).
  - Dual Mode Interface:
    - **Visual Mode (展示模式)**: Interactive cards with instant toggles, badges, and quick controls.
    - **Configuration Mode (配置模式)**: Direct text input of Whistle-compatible rules.
    - Bidirectional real-time sync between both modes.
  - Real-time rule activation without restarting the proxy.
  - Import / Export (.txt Whistle rules, .json).
  - Ultra-low memory usage (< 10-35MB) and sub-second cold launch (2.9 ms).
  - Zero interference with local Clash / system proxy: runs on dedicated port (default 9898) and never overrides system proxy without explicit request.
  - Complete UI verification with screenshots and documentation.
  - Acceptance report and publication to GitHub.

## 2. Technical Stack & Architecture
- **Language**: Swift 6.3 (macOS 26+ target)
- **GUI Framework**: SwiftUI + AppKit (`NSVisualEffectView` for Liquid Glass vibrancy, `MenuBarExtra` for status bar icon, `NavigationSplitView`)
- **Networking Core**: Apple `Network.framework` (`NWListener`, `NWConnection`) for high-performance, zero-overhead asynchronous proxy server.
- **Rule Parser**: Whistle rule grammar parser supporting Host, Remote, Mock, Header, Status, and comments.

## 3. Milestones & Task Checklist
- [x] **Milestone 1: Project Scaffold & Swift Package / App Bundle Setup**
  - [x] Package.swift / App structure configured.
  - [x] Initial `README.md` and `agent.md` created.
- [x] **Milestone 2: High-Performance Proxy Core & Rule Engine**
  - [x] `RuleEngine.swift`: Parser for Whistle rules, pattern matcher, bidirectional serializer.
  - [x] `ProxyServer.swift`: `Network.framework` based HTTP/HTTPS forward/reverse proxy handler.
  - [x] Dynamic rule update & isolated test verification.
- [x] **Milestone 3: macOS 26/27 Liquid Glass UI Implementation**
  - [x] `Theme.swift`: UI design tokens (materials, squircles, typography, semantic colors, accent).
  - [x] `VisualModeView.swift`: Card/Table view with toggles, badges, quick add/edit.
  - [x] `ConfigModeView.swift`: Whistle syntax text editor with live validation.
  - [x] `HeaderBarView.swift`: Mode switcher, traffic lights offset, quick stats, import/export buttons.
  - [x] `RuleEditSheet.swift`: Native macOS modal sheet.
- [x] **Milestone 4: Build, Run & CUA Screenshot Verification**
  - [x] Build release `.app`.
  - [x] Launch application.
  - [x] Test Visual Mode (01_visual_mode_initial.png).
  - [x] Test Configuration Mode (03_config_mode_text_editor.png).
  - [x] Test Rule addition and editing (04_add_rule_sheet.png, 05_rule_added_config_mode.png, 06_rule_added_visual_mode.png).
  - [x] Test real-time toggle activation (07_rule_toggled_off.png, 08_config_synced_after_toggle.png).
  - [x] Test category filtering (10_category_filter_mock.png, 11_filter_reset_all.png).
  - [x] Test isolated proxy response via curl on port 9898 (Mock response verified, Clash 100% unaffected).
  - [x] Benchmark memory consumption (9.4 MB) and cold launch time (2.9 ms).
- [x] **Milestone 5: Documentation & GitHub Release**
  - [x] Complete `README.md` with features, screenshots, and architecture.
  - [x] Produce `ACCEPTANCE_REPORT.md` with complete test evidence.
  - [x] Initialize Git repository, commit clean code.
  - [x] Create GitHub repository via `gh` and push to `https://github.com/guodonglu/WhistFlow`.
- [x] **Milestone 6: Light Mode, CLI Tool, Management API & Companion Skill**
  - [x] Light Mode (浅色模式) implementation with explicit switcher & system auto adaptation.
  - [x] Light Mode UI verification with screenshots (14_appearance_light.png, 15_appearance_light_config.png).
  - [x] Built-in Local REST Control API on `127.0.0.1:9898/_whistflow/api/` for dynamic control.
  - [x] Lightweight CLI controller `bin/whistflow` (zero dependencies, Python 3).
  - [x] Companion Skill `whistflow` installed to `~/.agents/skill/whistflow` with full documentation.
- [x] **Milestone 7: UI/UX Pro Max Optimization & Streamlined Interface**
  - [x] Removed redundant memory metrics from main UI.
  - [x] Light mode optical contrast enhancement with crisp borders, subtle shadows, and distinct card backgrounds.
  - [x] Removed "视图模式" picker label for ultra-minimalist header aesthetics.
  - [x] Verified with screenshots 16-21.
- [x] **Milestone 8: Rebranding to SimpleProxy & iOS 27 Liquid Glass App Icon**
  - [x] Rebranded application across all UI, ViewModel, CLI, and bundle manifests to `SimpleProxy`.
  - [x] Designed ultra-minimalist iOS 27 Liquid Glass app icon (Apple continuous squircle, optical glass caustics, glowing infinity proxy conduit).
  - [x] Generated multi-resolution `AppIcon.icns` (16x16 to 1024x1024) and linked into `SimpleProxy.app/Contents/Info.plist`.
  - [x] Updated CLI to `bin/simpleproxy` and installed `simpleproxy` skill into `~/.agents/skill/simpleproxy`.
  - [x] Verified with screenshots:
    - `22_simpleproxy_branded_window.png` (Light Visual Mode)
    - `23_simpleproxy_dark_mode.png` (Dark Visual Mode)
    - `24_simpleproxy_config_mode.png` (Config Code Mode)
  - [x] Updated documentation and pushed to GitHub.
  - [x] `whistflow` CLI executable script installed to `~/.local/bin/whistflow`.
  - [x] Official companion skill authored at `~/.agents/skill/whistflow/SKILL.md`.
- [x] **Milestone 7: UI/UX Pro Max Skill Installation & UI/UX De-cluttering Polish**
  - [x] Installed `ui-ux-pro-max` skill from `nextlevelbuilder/ui-ux-pro-max-skill` to `~/.agents/skill/ui-ux-pro-max/`.
  - [x] Eliminated redundant debug stats (removed "内存占用" from header bar and stopped background memory timer).
  - [x] Revamped Light Mode palette & materials: eliminated muddy gray tones, applied luminous clean white frosted glass cards and silky background gradient.
  - [x] Removed redundant "视图模式" picker label for clean, centered segmented control.
  - [x] Verified and captured screenshots `19_light_mode_no_picker_label.png`, `20_light_mode_config_no_picker_label.png`, and `21_dark_mode_no_picker_label.png`.

## 4. Current State
- All milestones fully delivered and verified.
- Production app: `SimpleProxy.app` (3.1 MB, native binary 1.2 MB + Retina AppIcon.icns).
- CLI tool: `simpleproxy` in `~/.local/bin/simpleproxy` (and `whistflow` alias).
- Agent Skills: `simpleproxy`, `ui-ux-pro-max`, and `whistflow` in `~/.agents/skill/`.
- GitHub repository: `https://github.com/guodonglu/WhistFlow`.
