# Overmap Zone System

## Overview

The zone system divides the overmap into three rotating "pie slice" regions that determine PvP rules and danger levels. Zones rotate periodically, ensuring all areas eventually cycle through all zone types.

## Zone Types

| Zone | Color | Weapons | Interdiction | Description |
|------|-------|---------|--------------|-------------|
| **Green** | `#88ff88` | Disabled | Disabled | Safe space - no PvP allowed |
| **Yellow** | `#ffff88` | Disabled | **Allowed** | Caution - boarding/piracy permitted, but no ship weapons |
| **Red** | `#ff8888` | **Allowed** | **Allowed** | Dangerous - full PvP, kill on sight |

**Note:** Ships cannot target each other across zone boundaries. Both ships must be in the same zone to acquire a weapons lock.

## How It Works

### Zone Layout
- Overmap is divided into 3 equal 120-degree wedges (pie slices) radiating from center
- Center area near the sun is always red (dangerous)
- Wedges rotate together like a clock when zones shift

### Zone Rotation
- Zones rotate every 30 minutes (configurable, currently 2 min for testing)
- Warnings at 5 minutes and 1 minute before shift (30s/10s for testing)
- Each rotation moves wedges by 120 degrees
- Announcements broadcast to all players

### Visual Feedback
- Overmap turfs are tinted with zone colors
- Helm console shows current zone + countdown timer
- Combat console shows zone banner with weapons status

### Zone Transitions
Crossing between zones requires a 10-second transition period:
- When a ship thrusts toward a different zone, the transition starts immediately
- Ship engines are cut and the ship stops
- Helm console shows transition progress and disables most controls
- **Cancellation:** Press the Stop button (which becomes "Cancel Transition") to abort
- After 10 seconds, the ship automatically moves into the new zone

This prevents exploits like darting into safe zones to escape combat.

## File Structure

```
voidcrew/
├── _DEFINES/
│   └── overmap_zones.dm          # Zone constants, signals, macros
├── modules/overmap/code/modules/overmap/zones/
│   ├── ZONES.md                  # This documentation
│   ├── zone_admin.dm             # Admin verbs (force shift, set rotation, status)
│   ├── zone_controller.dm        # SSovermap_zones subsystem
│   └── zone_datum.dm             # /datum/overmap_zone
```

## Key Files

### Defines (`voidcrew/_DEFINES/overmap_zones.dm`)
- `ZONE_GREEN`, `ZONE_YELLOW`, `ZONE_RED` - Zone type constants
- `ZONE_ROTATION_INTERVAL` - Time between rotations
- `ZONE_SHIFT_WARNING_TIME` - Warning announcement timing
- `ZONE_TRANSITION_TIME` - Time to cross zone boundaries (10 seconds)
- `COMSIG_*` signals for zone events
- `ZONE_WEAPONS_ALLOWED()`, `ZONE_INTERDICTION_ALLOWED()` macros

### Zone Controller (`zone_controller.dm`)
- `SSovermap_zones` subsystem manages everything
- `assign_zones()` - Assigns turfs to zones based on position/rotation
- `calculate_zone_for_turf()` - Determines zone type for a turf (pie slice algorithm)
- `perform_rotation()` - Executes zone shift
- `weapons_allowed_at(atom)` - Check if weapons allowed (finds ship, checks its zone)
- `interdiction_allowed_at(atom)` - Check if interdiction allowed
- `get_zone(turf)` - Fast zone lookup for overmap turfs

### Zone Datum (`zone_datum.dm`)
- `/datum/overmap_zone` - Represents a zone instance
- Tracks turfs belonging to zone
- Provides `weapons_allowed()`, `interdiction_allowed()`, `get_color()`, etc.

### Admin Verbs (`zone_admin.dm`)
- **Force Zone Shift** - Immediate rotation
- **Set Zone Rotation** - Set rotation angle (0-359)
- **Zone Status** - Show current zone stats

## Integration Points

### Weapon Restrictions
Weapons check zones via `SSovermap_zones.weapons_allowed_at(src)`:
- `voidcrew/modules/ship_combat/missile_launcher.dm` - `can_fire()` proc
- `voidcrew/modules/ship_combat/laser_turret.dm` - `can_fire()` proc
- `voidcrew/modules/ship_combat/interdictor.dm` - `can_interdict()` proc

### Cross-Zone Targeting
Ships cannot target each other across zone boundaries:
- `voidcrew/modules/ship_combat/combat_console.dm`:
  - `start_targeting()` - Blocks acquiring locks on ships in different zones
  - `check_targeting_range()` - Cancels in-progress targeting if ships enter different zones
  - `check_attack_range()` - Exits attack mode if locked target enters different zone
  - `ui_data()` - Sends zone info for each nearby ship so UI can show which are targetable
- Ships in different zones show as disabled in the targeting list with their zone name

### UI Integration
Zone data sent to TGUI via `ui_data()`:
- `voidcrew/modules/shuttle/helm/_helm.dm` - Helm console (zone + timer)
- `voidcrew/modules/ship_combat/combat_console.dm` - Combat console (zone + weapons status)

TGUI components:
- `tgui/packages/voidcrew_tgui/interfaces/HelmComputer.jsx` - ZoneSection component
- `tgui/packages/voidcrew_tgui/interfaces/ShipCombatConsole.tsx` - Zone banner

### Overmap Turf
- `voidcrew/modules/overmap/code/game/turfs/open/overmap.dm`
- `current_zone` var on `/turf/open/overmap`
- `update_zone_color()` proc for visual tinting

### Ship Zone Transitions (`voidcrew/modules/overmap/code/modules/overmap/ship.dm`)
Ships have vars and procs for zone transition handling:
- `zone_transitioning` - Boolean, TRUE when transitioning between zones
- `zone_transition_timer` - Timer ID for the 10s completion callback
- `zone_transition_target` - The turf we're trying to reach
- `zone_transition_start_time` - When transition started (for progress calculation)
- `start_zone_transition(turf, zone)` - Begin transition, stops engines
- `complete_zone_transition()` - Called after 10s, moves ship to new zone
- `cancel_zone_transition()` - Cancel via stop button

Zone detection happens in `burn_engines()` - when thrusting toward a different zone, the transition starts instead of normal thrust.

## Signals

| Signal | Sent By | Args | Description |
|--------|---------|------|-------------|
| `COMSIG_TURF_ZONE_CHANGED` | Zone datum | `(old_type, new_type)` | Turf's zone changed |
| `COMSIG_SHIP_ZONE_CHANGED` | Zone controller | `(old_type, new_type)` | Ship entered different zone |
| `COMSIG_GLOB_ZONE_SHIFT_WARNING` | Zone controller | `(seconds_remaining)` | Warning before shift |
| `COMSIG_GLOB_ZONE_SHIFT` | Zone controller | `(list/affected_turfs)` | Shift occurred |
| `COMSIG_GLOB_ZONE_ROTATION_COMPLETE` | Zone controller | none | Rotation finished |

## Future Hooks

The zone system is designed for expansion. Planned integrations:
- **Missions** - Higher payouts in dangerous zones
- **Planet weather** - Zone-based weather events
- **Mob spawns** - Different enemies per zone
- **Loot tables** - Better drops in red zones
- **NPC ships** - Traders in green, pirates in red

## Configuration

Current test values (in `overmap_zones.dm`):
```dm
#define ZONE_ROTATION_INTERVAL (2 MINUTES)      // Production: 30 MINUTES
#define ZONE_SHIFT_WARNING_TIME (30 SECONDS)    // Production: 5 MINUTES
#define ZONE_SHIFT_FINAL_WARNING_TIME (10 SECONDS) // Production: 1 MINUTES
#define ZONE_TRANSITION_TIME (10 SECONDS)       // Time to cross zone boundaries
```

## Troubleshooting

**Zones not appearing:**
- Check SSovermap_zones initialized (look for log messages)
- Verify SSovermap.overmap_centre exists
- Check init_order (zones must init AFTER overmap)

**Weapons still firing in safe zones:**
- `weapons_allowed_at()` must find the ship via `get_ship_from_atom()`
- Ship must be on overmap turf (not docked inside another ship)

**Zone colors not updating:**
- `update_all_turf_colors()` called after zone assignment
- Check turf is `/turf/open/overmap` type

**Zone transitions not working:**
- Check `SSovermap_zones.initialized` is TRUE
- Transition triggers on thrust (burn_engines), not movement
- Check `zone_transitioning` var on ship - should be TRUE during transition
- Verify zones are properly assigned to turfs via `SSovermap_zones.get_zone()`
- Check helm console for transition UI (notice box + progress bar in ZoneSection)
