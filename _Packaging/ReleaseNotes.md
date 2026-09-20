### Added
- Support for WoW 12.0.0 (Midnight)
- Library rework changes integrated (dev note: this change affects all addons and is a preparation for a better unified system for long term support)

### Added (9.1)
- Currencies that are at their maximum quantity are now shown in red in the tooltip

### Changed (9.1)
- Updated supported game versions: Retail 12.1.0, Mists of Pandaria Classic 5.5.4, Burning Crusade Anniversary 2.5.6 and Classic Era 1.15.9

### Fixed (9.1)
- Fixed the addon tainting the C_CurrencyInfo namespace on clients without the modern currency list API, which could block protected actions (dev note: the legacy GetCurrencyListSize/GetCurrencyListInfo shims are now file-local instead of being assigned into C_CurrencyInfo)