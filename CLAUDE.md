# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Krowi's Brokers [Currency] is a World of Warcraft LibDataBroker addon (Lua 5.1, WoW API) that shows gold and currencies on a broker bar, with per-character gold tracking, session profit/spend, and a right-click options menu. One TOC serves every flavor listed in `## Interface:` (Retail, Mists Classic, TBC Anniversary, Classic Era); flavor differences are handled at runtime with `addon.Util.IsMainline` and API-existence checks, never with separate TOCs.

There is no build, lint, or unit test step. The game is the test harness.

## Commands

- **Deploy to the game**: saving any file in VS Code copies the addon into every `H:\World of Warcraft\<flavor>\Interface\AddOns\Krowi_Brokers_Currency` listed in `.vscode/settings.json` (fsdeploy, `deployWorkspaceOnSave`). `/reload` in game afterwards. From the CLI: `& "E:\World of Warcraft Addon Development\Krowi_ClaudeKit\tools\Deploy.ps1" -Client Retail|Classic|Era|Anniversary` (`-WhatIf` first). The `krowi` plugin syntax-checks every edited `.lua` with Lua 5.1; otherwise the VS Code Lua language server config in `.vscode/settings.json` is the only static check.
- **Libraries**: `git submodule update --init --recursive` after cloning or when `Libs/` is empty. Bumping a library = checking out the wanted commit inside `Libs/<Lib>` and committing the pointer.
- **Release**: use the `krowi:release` skill from the `krowi` plugin (Krowi_ClaudeKit, enabled in `.claude/settings.json`). It is the only way to cut a version. Releases are cut on `main`, the only long-lived branch: branch from it and open PRs against it. Preflight is `& "E:\World of Warcraft Addon Development\Krowi_ClaudeKit\skills\release\Check-ReleaseReady.ps1" -Version <x.y>`; the packaging, commit, tag and uploads are done by the external Krowi Addon Manager, not by anything in this repo.
- **Workspace rules**: the shared rules for every Krowi repo (tooling traps, the game loop with the kit's `Deploy.ps1` and `Read-GameErrors.ps1`, taint, git, release safety) load from the workspace `CLAUDE.md` one folder up; this file adds only what is specific to this repo.

## Architecture

**Load order** is the TOC: `Libs\Files.xml` → `Localization\Files.xml` → `Currency.lua` → `CharacterData.lua` → `Tooltip.lua` → `Menu.lua` → `Krowi_Brokers_Currency.lua`. Every file starts with `local _, addon = ...` and publishes one module table (`addon.Currency`, `addon.CharacterData`, `addon.Tooltip`, `addon.Menu`). The main file runs last and wires everything together.

**Libraries are git submodules under `Libs/`** and are injected into `addon` by `Libs/Libs.lua` through `KROWI_LIBMAN:NewAddon` (from `Krowi_Util`):
- `addon.Util` (nested-key read/write helpers, `IsMainline`), `addon.Metadata` (TOC fields such as `Prefix`, `Title`, `Version`), `addon.Localization` / `addon.L`.
- `addon.MenuBuilder` from `Krowi_Menu`: all right-click menu items in `Menu.lua` are built with it; checkbox/radio items bind directly to paths in `KrowiBCU_Options`.
- `addon.Broker` from `Krowi_Brokers`: `InitBroker(addonName, addon, onEnter, onLeave, onClick, onEvent)` creates the LDB data object as `addon.LDB`, owns the event frame (`RegisterEvents`), and injects `addon.Menu.CreateElvUIOptionsMenu` / `CreateTitanOptionsMenu`. Call `addon.LDB:Update()` whenever the button text should refresh.
- `addon.CurrencyLib` = `Krowi_Currency_2`: money/currency formatting and the shared Money/Currency option submenus. Formatting always goes through `addon:FormatMoney` / `addon:FormatCurrency`, which pass `addon.GetOptionsForLib()`.
- `Krowi_Brokers` is shared with `Krowi_Brokers_Time` and `Krowi_Brokers_System`; a change there usually means releasing all three.

**Saved variables** (declared in the TOC, defaults merged key-by-key at load in the main file, so adding an option = adding a default there):
- `KrowiBCU_Options`: user settings. Header visibility lives under `HeaderSettings` keyed by `addon.GetHeaderSettingKey(headerName)` (`ShowHeader_<name with spaces→_>`); `nil` means visible.
- `KrowiBCU_SavedData`: `CharacterData` keyed `"<Name>-<Realm>"` (name, realm, money, faction, className, visible) plus session counters. Session tracking is updated as a side effect of `CharacterData.UpdateCharacterData()` on money events and expires after `SessionDuration` unless the periodic ticker keeps `SessionLastUpdate` fresh.

**Currency scanning** (`Currency.lua`) walks Blizzard's currency list, which is a flat list with collapsible headers. Collapsed headers must be expanded (`C_CurrencyInfo.ExpandCurrencyList`) before their children appear, so the scanners return `(finished, nextIndex)` and the callers loop until `finished`. `GetAllCurrenciesWithHeader` builds a nested header tree (`children`, `currencies`, `depth`) plus an ordered header-name list; `GetAllCurrencies` returns a flat list. On clients without `C_CurrencyInfo.GetCurrencyListInfo` the legacy globals are shimmed into **file-local** functions. Never assign into a `C_*` namespace: it taints the addon for the session and blocks protected calls.

**Tooltip** (`Tooltip.lua`) has three views (Money, Currency, Combined). `DefaultTooltip` picks the base view and holding Shift/Ctrl while hovering cycles to the others; the main file re-renders on modifier change via an `OnUpdate` throttle set in `OnEnter` and cleared in `OnLeave`.

## Localization

`Localization/enUS.lua` below the `AUTOGENTOKEN` marker is exported from CurseForge by the addon manager and is not hand-edited. New strings are used as `addon.L['Some Text']` in code, added on the CurseForge localization page, then re-exported. `Shared.lua` swaps `addon.L` for the active locale at load.

## Conventions

- Tabs for indentation, single quotes for strings, `tinsert` over `table.insert`, past-tense bullets in `_Packaging/Changelog.md` under `### Added` / `### Changed` / `### Fixed`.
- Every user-facing behavior change gets a changelog bullet in the top entry before release; the top entry header must read `## <version> - <YYYY-MM-DD>` or the release tooling fails to parse it.
- `README.md` and `_Packaging/ReleaseNotes.md` are generated by the release tooling from `_Packaging/Description.md` and the changelog. Edit the sources, not the outputs.
- `.vscode/settings.json` is committed and lists the WoW globals the Lua language server should accept; add new globals there rather than suppressing warnings inline.
