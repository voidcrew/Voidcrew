"""
DMI File Parser and Writer

Handles reading and writing BYOND DMI files, which are PNG images with
embedded metadata in a zTXt chunk.
"""

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional
from PIL import Image, PngImagePlugin
import base64
from io import BytesIO


# BYOND direction constants
SOUTH = 2
NORTH = 1
EAST = 4
WEST = 8
SOUTHEAST = 6
SOUTHWEST = 10
NORTHEAST = 5
NORTHWEST = 9

# Direction order for 4-dir and 8-dir sprites
DIR_ORDER_4 = [SOUTH, NORTH, EAST, WEST]
DIR_ORDER_8 = [SOUTH, NORTH, EAST, WEST, SOUTHEAST, SOUTHWEST, NORTHEAST, NORTHWEST]

DIR_NAMES = {
    SOUTH: "south",
    NORTH: "north",
    EAST: "east",
    WEST: "west",
    SOUTHEAST: "southeast",
    SOUTHWEST: "southwest",
    NORTHEAST: "northeast",
    NORTHWEST: "northwest"
}


@dataclass
class DMIState:
    """Represents a single icon state in a DMI file."""
    name: str
    dirs: int = 1
    frames: int = 1
    delay: list[float] = field(default_factory=list)
    loop: int = 0
    rewind: int = 0
    movement: int = 0
    hotspot: Optional[tuple[int, int]] = None

    # Runtime data - sprite images for each direction/frame
    # Key: (dir_index, frame_index), Value: PIL Image
    sprites: dict[tuple[int, int], Image.Image] = field(default_factory=dict)

    def total_sprites(self) -> int:
        """Total number of sprite images for this state."""
        return self.dirs * self.frames

    def get_sprite(self, direction: int = 0, frame: int = 0) -> Optional[Image.Image]:
        """Get a specific sprite by direction index and frame."""
        return self.sprites.get((direction, frame))

    def set_sprite(self, direction: int, frame: int, sprite: Image.Image):
        """Set a specific sprite."""
        self.sprites[(direction, frame)] = sprite


@dataclass
class DMIFile:
    """Represents a complete DMI file."""
    version: float = 4.0
    width: int = 32
    height: int = 32
    states: list[DMIState] = field(default_factory=list)
    source_path: Optional[Path] = None

    def get_state(self, name: str) -> Optional[DMIState]:
        """Get a state by name."""
        for state in self.states:
            if state.name == name:
                return state
        return None

    def get_state_names(self) -> list[str]:
        """Get all state names."""
        return [s.name for s in self.states]

    def total_sprites(self) -> int:
        """Total number of sprites across all states."""
        return sum(s.total_sprites() for s in self.states)


def parse_dmi_metadata(metadata_text: str) -> tuple[float, int, int, list[dict]]:
    """
    Parse DMI metadata text into structured data.

    Returns: (version, width, height, list of state dicts)
    """
    lines = metadata_text.strip().split('\n')

    # Validate format
    if not lines or lines[0].strip() != '# BEGIN DMI':
        raise ValueError("Invalid DMI format: missing '# BEGIN DMI' header")
    if lines[-1].strip() != '# END DMI':
        raise ValueError("Invalid DMI format: missing '# END DMI' footer")

    version = 4.0
    width = 32
    height = 32
    states = []
    current_state = None

    for line in lines[1:-1]:
        line = line.strip()
        if not line:
            continue

        if line.startswith('version'):
            match = re.match(r'version\s*=\s*(\d+\.?\d*)', line)
            if match:
                version = float(match.group(1))

        elif line.startswith('width'):
            match = re.match(r'width\s*=\s*(\d+)', line)
            if match:
                width = int(match.group(1))

        elif line.startswith('height'):
            match = re.match(r'height\s*=\s*(\d+)', line)
            if match:
                height = int(match.group(1))

        elif line.startswith('state'):
            # Save previous state
            if current_state is not None:
                states.append(current_state)

            # Parse state name (can be empty string)
            match = re.match(r'state\s*=\s*"([^"]*)"', line)
            if match:
                current_state = {'name': match.group(1)}
            else:
                current_state = {'name': ''}

        elif current_state is not None and '=' in line:
            # Parse state properties
            key, value = line.split('=', 1)
            key = key.strip()
            value = value.strip()

            if key == 'dirs':
                current_state['dirs'] = int(value)
            elif key == 'frames':
                current_state['frames'] = int(value)
            elif key == 'delay':
                current_state['delay'] = [float(x.strip()) for x in value.split(',')]
            elif key == 'loop':
                current_state['loop'] = int(value)
            elif key == 'rewind':
                current_state['rewind'] = int(value)
            elif key == 'movement':
                current_state['movement'] = int(value)
            elif key == 'hotspot':
                parts = value.split(',')
                if len(parts) >= 2:
                    current_state['hotspot'] = (int(parts[0].strip()), int(parts[1].strip()))

    # Don't forget the last state
    if current_state is not None:
        states.append(current_state)

    return version, width, height, states


def load_dmi(filepath: str | Path) -> DMIFile:
    """
    Load a DMI file and parse its contents.

    Args:
        filepath: Path to the DMI file

    Returns:
        DMIFile object with all states and sprites loaded
    """
    filepath = Path(filepath)

    # Open the image
    img = Image.open(filepath)

    # Get the DMI metadata from the zTXt chunk
    metadata_text = img.text.get('Description', '')
    if not metadata_text:
        raise ValueError(f"No DMI metadata found in {filepath}")

    # Parse metadata
    version, width, height, state_dicts = parse_dmi_metadata(metadata_text)

    # Create DMI file object
    dmi = DMIFile(
        version=version,
        width=width,
        height=height,
        source_path=filepath
    )

    # Calculate grid dimensions
    img_width, img_height = img.size
    cols = img_width // width
    rows = img_height // height

    # Extract sprites for each state
    sprite_index = 0

    for state_dict in state_dicts:
        state = DMIState(
            name=state_dict.get('name', ''),
            dirs=state_dict.get('dirs', 1),
            frames=state_dict.get('frames', 1),
            delay=state_dict.get('delay', []),
            loop=state_dict.get('loop', 0),
            rewind=state_dict.get('rewind', 0),
            movement=state_dict.get('movement', 0),
            hotspot=state_dict.get('hotspot')
        )

        # Extract each sprite for this state
        for dir_idx in range(state.dirs):
            for frame_idx in range(state.frames):
                # Calculate position in grid
                row = sprite_index // cols
                col = sprite_index % cols

                # Extract sprite
                x = col * width
                y = row * height
                sprite = img.crop((x, y, x + width, y + height))

                state.set_sprite(dir_idx, frame_idx, sprite.copy())
                sprite_index += 1

        dmi.states.append(state)

    return dmi


def generate_dmi_metadata(dmi: DMIFile) -> str:
    """Generate DMI metadata text from a DMIFile object."""
    lines = ['# BEGIN DMI']
    lines.append(f'version = {dmi.version}')
    lines.append(f'\twidth = {dmi.width}')
    lines.append(f'\theight = {dmi.height}')

    for state in dmi.states:
        lines.append(f'state = "{state.name}"')
        lines.append(f'\tdirs = {state.dirs}')
        lines.append(f'\tframes = {state.frames}')

        if state.delay:
            delay_str = ','.join(str(int(d)) for d in state.delay)
            lines.append(f'\tdelay = {delay_str}')

        if state.loop:
            lines.append(f'\tloop = {state.loop}')

        if state.rewind:
            lines.append(f'\trewind = {state.rewind}')

        if state.movement:
            lines.append(f'\tmovement = {state.movement}')

        if state.hotspot:
            lines.append(f'\thotspot = {state.hotspot[0]},{state.hotspot[1]}')

    lines.append('# END DMI')
    return '\n'.join(lines)


def save_dmi(dmi: DMIFile, filepath: str | Path):
    """
    Save a DMIFile to disk.

    Args:
        dmi: The DMIFile object to save
        filepath: Output path
    """
    filepath = Path(filepath)

    # Calculate required sprite sheet dimensions
    total_sprites = dmi.total_sprites()

    # Try to make a reasonably square grid
    cols = max(1, int(total_sprites ** 0.5))
    while total_sprites % cols != 0 and cols > 1:
        cols -= 1
    rows = (total_sprites + cols - 1) // cols

    # Create sprite sheet
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

    # Generate metadata
    metadata_text = generate_dmi_metadata(dmi)

    # Save with zTXt chunk
    pnginfo = PngImagePlugin.PngInfo()
    pnginfo.add_text('Description', metadata_text, zip=True)

    sheet.save(filepath, format='PNG', pnginfo=pnginfo)


def sprite_to_base64(sprite: Image.Image, format: str = 'PNG') -> str:
    """Convert a PIL Image to base64 string."""
    buffer = BytesIO()
    sprite.save(buffer, format=format)
    return base64.b64encode(buffer.getvalue()).decode('utf-8')


def base64_to_sprite(data: str) -> Image.Image:
    """Convert a base64 string to PIL Image."""
    image_data = base64.b64decode(data)
    return Image.open(BytesIO(image_data))


def get_direction_name(dir_index: int, total_dirs: int) -> str:
    """Get human-readable direction name from index."""
    if total_dirs == 1:
        return "default"
    elif total_dirs == 4:
        return DIR_NAMES.get(DIR_ORDER_4[dir_index], f"dir{dir_index}")
    elif total_dirs == 8:
        return DIR_NAMES.get(DIR_ORDER_8[dir_index], f"dir{dir_index}")
    return f"dir{dir_index}"
