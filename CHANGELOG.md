# Changelog

All notable changes to PurpleNotes will be documented in this file.

## [0.2] - 2026-01-23

### Added
- Multi-note system with unlimited note support
- Editable note titles in the title bar
- Navigation arrows to switch between notes
- Menu system with note selection dropdown
- Delete functionality with confirmation dialogs
- Tooltips for truncated note names in the note list
- Auto-close menu when clicking outside
- Data migration from single-note format (v0.1) to multi-note format
- `/pn reset` command to reset all notes and settings

### Changed
- Improved drag behavior to prevent accidental drags when interacting with UI elements
- Enhanced resize functionality with better state management
- Title bar now includes menu button, navigation arrows, and note title field
- Window now hides on addon load (use `/pn` to show)
- Updated frame layout to accommodate title bar elements

### Fixed
- Resize snap issue that occurred when dragging after resizing
- Title text truncation after window resize
- Cursor positioning in title edit box
- Multiple closure bugs in delete button handlers
- Active note deletion logic now properly handles edge cases

## [0.1] - 2026-01-22

### Added
- Initial release
- Single-note functionality
- Draggable and resizable window
- Purple text on semi-transparent black background
- Auto-save functionality
- `/pn` and `/purplenotes` commands to toggle window
- Position and size persistence
