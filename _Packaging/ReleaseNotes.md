### Changed
- Extracted broker initialization logic into new Krowi_Brokers-1.0 library for reuse across addons
- Refactored event registration and initialization flow to use centralized broker library
- Improved code organization by consolidating broker setup into standardized library calls

### Added (7.1)
- "Right-Click: Options" hint to tooltip

### Changed (7.1)
- Removed unused self parameter from OnEvent function
- Updated Krowi_Brokers library
- Updated Krowi_Menu library

### Fixed (7.1)
- Removed obsolete Krowi_PopupDialog submodule references from .gitmodules