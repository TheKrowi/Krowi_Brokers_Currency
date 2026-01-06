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

### Fixed (7.2)
- Fixed Krowi_Brokers library to properly handle multiple addon instances by passing addon context as parameters
- Fixed Menu.ShowPopup to accept caller parameter for proper context menu positioning

### Changed (7.2)
- Simplified InitBroker call by removing redundant parameters now handled by the library
- Updated Krowi_Brokers library to version with multi-addon support
- Improved menu refresh callback organization