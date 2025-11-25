# DMI Editor MCP Server

An MCP (Model Context Protocol) server that provides tools for reading, editing, and writing BYOND DMI files.

## Features

- **Read DMI files**: Get metadata, list states, extract individual sprites
- **Edit DMI files**: Replace sprites, add/delete/rename states, modify state properties
- **Write DMI files**: Save changes back to DMI format
- **Export**: Export sprite sheets as PNG

## Installation

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Add to Claude Code:
```bash
claude mcp add dmi-editor -- python C:\Users\isaac\code\tg-voidcrew\tools\dmi-mcp-server\server.py
```

## Tools

### Reading

- `dmi_info` - Get full information about a DMI file
- `dmi_list_states` - List all state names
- `dmi_get_state` - Get detailed info about one state
- `dmi_extract_sprite` - Extract a single sprite as base64 PNG
- `dmi_extract_state_sprites` - Extract all sprites for a state

### Editing

- `dmi_replace_sprite` - Replace a sprite with new image data
- `dmi_add_state` - Add a new icon state
- `dmi_delete_state` - Delete an icon state
- `dmi_rename_state` - Rename an icon state
- `dmi_modify_state` - Modify state properties (delay, loop, etc.)

### Saving

- `dmi_save` - Save changes to disk
- `dmi_reload` - Reload from disk (discard changes)
- `dmi_export_spritesheet` - Export as PNG spritesheet
- `dmi_create_new` - Create a new empty DMI file

## Usage Example

```
# Get info about a DMI file
dmi_info("C:/path/to/file.dmi")

# Extract a sprite
dmi_extract_sprite("C:/path/to/file.dmi", "state_name", direction=0, frame=0)

# Make changes and save
dmi_rename_state("C:/path/to/file.dmi", "old_name", "new_name")
dmi_save("C:/path/to/file.dmi")
```

## DMI Format Notes

- DMI files are PNG images with metadata in a zTXt chunk
- Direction order for 4-dir: SOUTH, NORTH, EAST, WEST (indices 0-3)
- Direction order for 8-dir: SOUTH, NORTH, EAST, WEST, SE, SW, NE, NW (indices 0-7)
- Delays are in deciseconds (1/10th of a second)
