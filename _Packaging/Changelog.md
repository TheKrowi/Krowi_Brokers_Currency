# Changelog
All notable changes to this project will be documented in this file.

## 7.0 - 2026-01-03
### Changed
- Extracted broker initialization logic into new Krowi_Brokers-1.0 library for reuse across addons
- Refactored event registration and initialization flow to use centralized broker library
- Improved code organization by consolidating broker setup into standardized library calls

## 6.0 - 2026-01-03
### Changed
- Split saved variables into KrowiBCU_Options (settings) and KrowiBCU_SavedData (character data) for better organization (dev note: this will unfortunately reset all settings to defaults)
- Major code refactoring: Reorganized initialization order and improved code structure throughout main file
- Fixed prefix/acronym in TOC file from KrowiBC/KBC to KrowiBCU/KBCU for consistency
- Added localized category tags in TOC file for better addon manager organization

## 5.2 - 2026-01-02
### Mists Classic
- Fixed issue where currencies were not properly displayed

## 5.1 - 2026-01-02
### Fixed
- Multi addon library usage errors

## 5.0 - 2026-01-02
### Changed
- Refactored currency and money formatting into new Krowi_Currency-1.0 library for reuse across addons
- Extracted formatting functions: FormatMoney(), FormatCurrency(), and supporting utilities into standalone library

## 4.0 - 2025-12-29
### Changed
- Menu generation and handling (dev note: for classic user this should be an invisible change; for mainline users this should reflect in modern looking drop down menus)

### Mists Classic
- Added support

### WoW Classic
- Added support

## 3.3 - 2025-12-08
### Changed
- Packaging

## 3.2 - 2025-11-28
### Added
- WoW Token current market price display in money tooltip (can be toggled on/off)
- Faction icons next to character names in tooltip for easy Alliance/Horde identification

## 3.1 - 2025-11-28
### Fixed
- Titan Panel base options integration for proper plugin configuration

## 3.0 - 2025-11-27
### Added
- Session gold tracking: Monitor earned and spent gold during play sessions
- Configurable session duration (1-48 hours) with automatic extension while playing
- Session data persistence across character changes and reloads
- Track Session Gold option to enable/disable tracking (auto-resets when disabled)
- Session profit/spent display in money tooltip with color-coded values (green/red)
- Multiple button display modes: Character Gold, Current Faction Total, Realm Total, Account Total, Warband Bank
- Combined tooltip mode showing both money and currencies with Ctrl/Shift modifiers
- Section headers in right-click menu for better organization

### Changed
- Menu reorganized into logical sections: Button Display, Tooltip Options, Money Options, Currency Options

## 2.0 - 2025-11-24
### Changed
- Total rewrite with improved functionality

## 1.0 - 2025-11-14
### Fixed
- TitanPanelChildButtonTemplate errors