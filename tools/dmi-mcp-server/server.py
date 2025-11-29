"""
DMI Editor MCP Server

An MCP server that provides tools for reading, editing, and writing BYOND DMI files.
"""

import sys
import logging
from pathlib import Path
from typing import Optional

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from mcp.server.fastmcp import FastMCP
from dmi_parser import (
    load_dmi,
    save_dmi,
    DMIFile,
    DMIState,
    sprite_to_base64,
    base64_to_sprite,
    get_direction_name,
    DIR_NAMES
)

# Configure logging to stderr (CRITICAL for stdio MCP servers)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stderr
)
logger = logging.getLogger(__name__)

# Create MCP server
mcp = FastMCP("dmi-editor")

# Cache loaded DMI files for performance
_dmi_cache: dict[str, DMIFile] = {}


def _get_dmi(filepath: str, force_reload: bool = False) -> DMIFile:
    """Get a DMI file from cache or load it."""
    filepath = str(Path(filepath).resolve())

    if force_reload or filepath not in _dmi_cache:
        logger.info(f"Loading DMI file: {filepath}")
        _dmi_cache[filepath] = load_dmi(filepath)

    return _dmi_cache[filepath]


def _clear_cache(filepath: Optional[str] = None):
    """Clear the DMI cache."""
    if filepath:
        filepath = str(Path(filepath).resolve())
        _dmi_cache.pop(filepath, None)
    else:
        _dmi_cache.clear()


# ============================================================================
# MCP Tools
# ============================================================================

@mcp.tool()
def dmi_info(file_path: str) -> dict:
    """
    Get information about a DMI file including all icon states.

    Args:
        file_path: Absolute path to the DMI file

    Returns:
        Dictionary with DMI metadata and state information
    """
    logger.info(f"Getting info for: {file_path}")

    try:
        dmi = _get_dmi(file_path)

        states_info = []
        for state in dmi.states:
            state_info = {
                "name": state.name,
                "dirs": state.dirs,
                "frames": state.frames,
                "total_sprites": state.total_sprites(),
            }
            if state.delay:
                state_info["delay"] = state.delay
            if state.loop:
                state_info["loop"] = state.loop
            if state.rewind:
                state_info["rewind"] = state.rewind
            if state.movement:
                state_info["movement"] = state.movement
            if state.hotspot:
                state_info["hotspot"] = state.hotspot

            states_info.append(state_info)

        return {
            "status": "success",
            "file_path": file_path,
            "version": dmi.version,
            "sprite_size": {"width": dmi.width, "height": dmi.height},
            "total_states": len(dmi.states),
            "total_sprites": dmi.total_sprites(),
            "states": states_info
        }

    except Exception as e:
        logger.error(f"Error loading DMI: {e}", exc_info=True)
        return {"status": "error", "message": str(e)}


@mcp.tool()
def dmi_list_states(file_path: str) -> dict:
    """
    List all icon state names in a DMI file.

    Args:
        file_path: Absolute path to the DMI file

    Returns:
        List of state names
    """
    try:
        dmi = _get_dmi(file_path)
        return {
            "status": "success",
            "states": dmi.get_state_names(),
            "count": len(dmi.states)
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}


@mcp.tool()
def dmi_get_state(file_path: str, state_name: str) -> dict:
    """
    Get detailed information about a specific icon state.

    Args:
        file_path: Absolute path to the DMI file
        state_name: Name of the state to get info for

    Returns:
        Detailed state information including sprite data
    """
    try:
        dmi = _get_dmi(file_path)
        state = dmi.get_state(state_name)

        if not state:
            return {"status": "error", "message": f"State '{state_name}' not found"}

        # Build sprite info
        sprites = []
        for dir_idx in range(state.dirs):
            for frame_idx in range(state.frames):
                sprite = state.get_sprite(dir_idx, frame_idx)
                if sprite:
                    sprites.append({
                        "direction": get_direction_name(dir_idx, state.dirs),
                        "direction_index": dir_idx,
                        "frame": frame_idx,
                        "size": sprite.size
                    })

        return {
            "status": "success",
            "state": {
                "name": state.name,
                "dirs": state.dirs,
                "frames": state.frames,
                "delay": state.delay,
                "loop": state.loop,
                "rewind": state.rewind,
                "movement": state.movement,
                "hotspot": state.hotspot,
                "sprites": sprites
            }
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}


@mcp.tool()
def dmi_extract_sprite(
    file_path: str,
    state_name: str,
    direction: int = 0,
    frame: int = 0
) -> dict:
    """
    Extract a single sprite from a DMI file as base64 PNG.

    Args:
        file_path: Absolute path to the DMI file
        state_name: Name of the icon state
        direction: Direction index (0=south, 1=north, 2=east, 3=west for 4-dir)
        frame: Animation frame index (0-based)

    Returns:
        Base64-encoded PNG image data
    """
    try:
        dmi = _get_dmi(file_path)
        state = dmi.get_state(state_name)

        if not state:
            return {"status": "error", "message": f"State '{state_name}' not found"}

        if direction >= state.dirs:
            return {"status": "error", "message": f"Direction {direction} out of range (max {state.dirs - 1})"}

        if frame >= state.frames:
            return {"status": "error", "message": f"Frame {frame} out of range (max {state.frames - 1})"}

        sprite = state.get_sprite(direction, frame)
        if not sprite:
            return {"status": "error", "message": "Sprite not found"}

        return {
            "status": "success",
            "state_name": state_name,
            "direction": get_direction_name(direction, state.dirs),
            "direction_index": direction,
            "frame": frame,
            "size": {"width": sprite.width, "height": sprite.height},
            "image_base64": sprite_to_base64(sprite),
            "mime_type": "image/png"
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}


@mcp.tool()
def dmi_extract_state_sprites(
    file_path: str,
    state_name: str,
    max_sprites: int = 16
) -> dict:
    """
    Extract all sprites for an icon state as base64 PNGs.

    Args:
        file_path: Absolute path to the DMI file
        state_name: Name of the icon state
        max_sprites: Maximum number of sprites to return (default 16)

    Returns:
        List of base64-encoded PNG images with metadata
    """
    try:
        dmi = _get_dmi(file_path)
        state = dmi.get_state(state_name)

        if not state:
            return {"status": "error", "message": f"State '{state_name}' not found"}

        sprites = []
        count = 0

        for dir_idx in range(state.dirs):
            for frame_idx in range(state.frames):
                if count >= max_sprites:
                    break

                sprite = state.get_sprite(dir_idx, frame_idx)
                if sprite:
                    sprites.append({
                        "direction": get_direction_name(dir_idx, state.dirs),
                        "direction_index": dir_idx,
                        "frame": frame_idx,
                        "image_base64": sprite_to_base64(sprite),
                        "mime_type": "image/png"
                    })
                    count += 1

            if count >= max_sprites:
                break

        return {
            "status": "success",
            "state_name": state_name,
            "total_sprites": state.total_sprites(),
            "sprites_returned": len(sprites),
            "truncated": len(sprites) < state.total_sprites(),
            "sprites": sprites
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}


@mcp.tool()
def dmi_replace_sprite(
    file_path: str,
    state_name: str,
    image_base64: str,
    direction: int = 0,
    frame: int = 0
) -> dict:
    """
    Replace a sprite in a DMI file with a new image.

    Note: This modifies the cached DMI. Use dmi_save to write changes to disk.

    Args:
        file_path: Absolute path to the DMI file
        state_name: Name of the icon state
        image_base64: Base64-encoded PNG image data
        direction: Direction index to replace
        frame: Frame index to replace

    Returns:
        Status of the operation
    """
    try:
        dmi = _get_dmi(file_path)
        state = dmi.get_state(state_name)

        if not state:
            return {"status": "error", "message": f"State '{state_name}' not found"}

        if direction >= state.dirs:
            return {"status": "error", "message": f"Direction {direction} out of range"}

        if frame >= state.frames:
            return {"status": "error", "message": f"Frame {frame} out of range"}

        # Decode the new sprite
        new_sprite = base64_to_sprite(image_base64)

        # Resize if needed to match DMI dimensions
        if new_sprite.size != (dmi.width, dmi.height):
            new_sprite = new_sprite.resize((dmi.width, dmi.height))

        # Ensure RGBA mode
        if new_sprite.mode != 'RGBA':
            new_sprite = new_sprite.convert('RGBA')

        # Replace the sprite
        state.set_sprite(direction, frame, new_sprite)

        return {
            "status": "success",
            "message": f"Replaced sprite in state '{state_name}' dir={direction} frame={frame}",
            "note": "Changes are cached. Use dmi_save to write to disk."
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}


@mcp.tool()
def dmi_add_state(
    file_path: str,
    state_name: str,
    dirs: int = 1,
    frames: int = 1,
    delay: list[float] = None
) -> dict:
    """
    Add a new empty icon state to a DMI file.

    Args:
        file_path: Absolute path to the DMI file
        state_name: Name for the new state
        dirs: Number of directions (1, 4, or 8)
        frames: Number of animation frames
        delay: Animation delays in deciseconds (optional)

    Returns:
        Status of the operation
    """
    try:
        dmi = _get_dmi(file_path)

        # Check if state already exists
        if dmi.get_state(state_name):
            return {"status": "error", "message": f"State '{state_name}' already exists"}

        # Validate dirs
        if dirs not in [1, 4, 8]:
            return {"status": "error", "message": "dirs must be 1, 4, or 8"}

        # Create new state with empty sprites
        from PIL import Image
        new_state = DMIState(
            name=state_name,
            dirs=dirs,
            frames=frames,
            delay=delay or []
        )

        # Create empty transparent sprites
        for dir_idx in range(dirs):
            for frame_idx in range(frames):
                empty_sprite = Image.new('RGBA', (dmi.width, dmi.height), (0, 0, 0, 0))
                new_state.set_sprite(dir_idx, frame_idx, empty_sprite)

        dmi.states.append(new_state)

        return {
            "status": "success",
            "message": f"Added state '{state_name}' with {dirs} dirs and {frames} frames",
            "note": "Changes are cached. Use dmi_save to write to disk."
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}


@mcp.tool()
def dmi_delete_state(file_path: str, state_name: str) -> dict:
    """
    Delete an icon state from a DMI file.

    Args:
        file_path: Absolute path to the DMI file
        state_name: Name of the state to delete

    Returns:
        Status of the operation
    """
    try:
        dmi = _get_dmi(file_path)

        for i, state in enumerate(dmi.states):
            if state.name == state_name:
                dmi.states.pop(i)
                return {
                    "status": "success",
                    "message": f"Deleted state '{state_name}'",
                    "note": "Changes are cached. Use dmi_save to write to disk."
                }

        return {"status": "error", "message": f"State '{state_name}' not found"}

    except Exception as e:
        return {"status": "error", "message": str(e)}


@mcp.tool()
def dmi_rename_state(file_path: str, old_name: str, new_name: str) -> dict:
    """
    Rename an icon state in a DMI file.

    Args:
        file_path: Absolute path to the DMI file
        old_name: Current state name
        new_name: New state name

    Returns:
        Status of the operation
    """
    try:
        dmi = _get_dmi(file_path)

        # Check if new name already exists
        if dmi.get_state(new_name):
            return {"status": "error", "message": f"State '{new_name}' already exists"}

        state = dmi.get_state(old_name)
        if not state:
            return {"status": "error", "message": f"State '{old_name}' not found"}

        state.name = new_name

        return {
            "status": "success",
            "message": f"Renamed state '{old_name}' to '{new_name}'",
            "note": "Changes are cached. Use dmi_save to write to disk."
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}


@mcp.tool()
def dmi_modify_state(
    file_path: str,
    state_name: str,
    delay: list[float] = None,
    loop: int = None,
    rewind: int = None,
    movement: int = None,
    hotspot: tuple[int, int] = None
) -> dict:
    """
    Modify properties of an icon state.

    Args:
        file_path: Absolute path to the DMI file
        state_name: Name of the state to modify
        delay: New animation delays (optional)
        loop: New loop value (optional)
        rewind: New rewind value (optional)
        movement: New movement value (optional)
        hotspot: New hotspot coordinates (optional)

    Returns:
        Status of the operation
    """
    try:
        dmi = _get_dmi(file_path)
        state = dmi.get_state(state_name)

        if not state:
            return {"status": "error", "message": f"State '{state_name}' not found"}

        changes = []

        if delay is not None:
            state.delay = delay
            changes.append("delay")

        if loop is not None:
            state.loop = loop
            changes.append("loop")

        if rewind is not None:
            state.rewind = rewind
            changes.append("rewind")

        if movement is not None:
            state.movement = movement
            changes.append("movement")

        if hotspot is not None:
            state.hotspot = hotspot
            changes.append("hotspot")

        return {
            "status": "success",
            "message": f"Modified state '{state_name}': {', '.join(changes)}",
            "note": "Changes are cached. Use dmi_save to write to disk."
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}


@mcp.tool()
def dmi_save(file_path: str, output_path: str = None) -> dict:
    """
    Save a modified DMI file to disk.

    Args:
        file_path: Path to the original DMI file (must be in cache)
        output_path: Output path (defaults to original path)

    Returns:
        Status of the operation
    """
    try:
        resolved_path = str(Path(file_path).resolve())

        if resolved_path not in _dmi_cache:
            return {"status": "error", "message": "DMI file not in cache. Load it first with dmi_info."}

        dmi = _dmi_cache[resolved_path]
        output = Path(output_path) if output_path else Path(file_path)

        save_dmi(dmi, output)

        return {
            "status": "success",
            "message": f"Saved DMI to {output}",
            "output_path": str(output)
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}


@mcp.tool()
def dmi_reload(file_path: str) -> dict:
    """
    Reload a DMI file from disk, discarding any cached changes.

    Args:
        file_path: Absolute path to the DMI file

    Returns:
        Status of the operation
    """
    try:
        _clear_cache(file_path)
        _get_dmi(file_path, force_reload=True)

        return {
            "status": "success",
            "message": f"Reloaded {file_path} from disk"
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}


@mcp.tool()
def dmi_export_spritesheet(file_path: str, output_path: str) -> dict:
    """
    Export the entire DMI as a PNG spritesheet.

    Args:
        file_path: Absolute path to the DMI file
        output_path: Path for the output PNG file

    Returns:
        Status with spritesheet information
    """
    try:
        dmi = _get_dmi(file_path)

        # Calculate dimensions
        total_sprites = dmi.total_sprites()
        cols = max(1, int(total_sprites ** 0.5))
        while total_sprites % cols != 0 and cols > 1:
            cols -= 1
        rows = (total_sprites + cols - 1) // cols

        from PIL import Image
        sheet_width = cols * dmi.width
        sheet_height = rows * dmi.height
        sheet = Image.new('RGBA', (sheet_width, sheet_height), (0, 0, 0, 0))

        # Place sprites
        sprite_index = 0
        for state in dmi.states:
            for dir_idx in range(state.dirs):
                for frame_idx in range(state.frames):
                    sprite = state.get_sprite(dir_idx, frame_idx)
                    if sprite:
                        row = sprite_index // cols
                        col = sprite_index % cols
                        x = col * dmi.width
                        y = row * dmi.height
                        sheet.paste(sprite, (x, y))
                    sprite_index += 1

        output = Path(output_path)
        sheet.save(output, 'PNG')

        return {
            "status": "success",
            "output_path": str(output),
            "dimensions": {"width": sheet_width, "height": sheet_height},
            "grid": {"cols": cols, "rows": rows},
            "total_sprites": total_sprites
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}


@mcp.tool()
def dmi_create_new(
    output_path: str,
    width: int = 32,
    height: int = 32
) -> dict:
    """
    Create a new empty DMI file.

    Args:
        output_path: Path for the new DMI file
        width: Sprite width (default 32)
        height: Sprite height (default 32)

    Returns:
        Status of the operation
    """
    try:
        # Create empty DMI
        dmi = DMIFile(
            version=4.0,
            width=width,
            height=height,
            states=[]
        )

        # Add a default empty state
        from PIL import Image
        default_state = DMIState(name="", dirs=1, frames=1)
        default_state.set_sprite(0, 0, Image.new('RGBA', (width, height), (0, 0, 0, 0)))
        dmi.states.append(default_state)

        # Save
        output = Path(output_path)
        save_dmi(dmi, output)

        # Cache it
        resolved = str(output.resolve())
        _dmi_cache[resolved] = dmi

        return {
            "status": "success",
            "message": f"Created new DMI file at {output}",
            "sprite_size": {"width": width, "height": height}
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}


# Run the server
if __name__ == "__main__":
    logger.info("Starting DMI Editor MCP Server")
    mcp.run(transport="stdio")
