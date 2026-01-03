# Overmap Zone System

## Overview

The zone system divides the overmap into concentric rings based on distance from the center (sun). Zones closer to the sun are more dangerous, while the outer edges and spawn area are safe.

## Zone Types

| Zone | Color | Weapons | Interdiction | Radiation | Description |
|------|-------|---------|--------------|-----------|-------------|
| **Neutral** | `#88ff88` | Disabled | Disabled | None | Safe space - no PvP allowed |
| **Contested** | `#ffff88` | Disabled | **Allowed** | Moderate | Caution - boarding/piracy permitted, but no ship weapons |
| **Lawless** | `#ff8888` | **Allowed** | **Allowed** | Heavy | Dangerous - full PvP, kill on sight |

**Targeting Rules:** Ships can only target each other if both are in Contested or Lawless zones. Neutral zone is a safe zone where targeting is disabled.

**Radiation:** Zones closer to the sun have higher solar radiation. Ships need appropriate shielding to protect crew.

## How It Works

### Zone Layout
Zones are organized as concentric rings based on distance from the center (sun), roughly equal in size:

1. **Inner Ring** (< 33% of map radius) - Lawless - Dangerous, close to sun
2. **Middle Ring** (33-66% of map radius) - Contested - Caution zone
3. **Outer Ring** (> 66% of map radius) - Neutral - Safe, edge of map

### Visual Feedback
- Overmap turfs are tinted with zone colors
- Helm console shows current zone with weapons/interdiction status
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
│   ├── zone_admin.dm             # Admin verbs (zone status)
│   ├── zone_controller.dm        # SSovermap_zones subsystem
│   └── zone_datum.dm             # /datum/overmap_zone
```

## Key Files

### Defines (`voidcrew/_DEFINES/overmap_zones.dm`)
- `ZONE_GREEN`, `ZONE_YELLOW`, `ZONE_RED` - Zone type constants (Neutral, Contested, Lawless)
- `ZONE_TRANSITION_TIME` - Time to cross zone boundaries (10 seconds)
- `COMSIG_*` signals for zone events
- `ZONE_WEAPONS_ALLOWED()`, `ZONE_INTERDICTION_ALLOWED()` macros

### Zone Controller (`zone_controller.dm`)
- `SSovermap_zones` subsystem manages everything
- `assign_zones()` - Assigns turfs to zones based on distance from center
- `calculate_zone_for_turf()` - Determines zone type for a turf (distance-based rings)
- `weapons_allowed_at(atom)` - Check if weapons allowed (finds ship, checks its zone)
- `interdiction_allowed_at(atom)` - Check if interdiction allowed
- `get_zone(turf)` - Fast zone lookup for overmap turfs

### Zone Datum (`zone_datum.dm`)
- `/datum/overmap_zone` - Represents a zone instance
- Tracks turfs belonging to zone
- Provides `weapons_allowed()`, `interdiction_allowed()`, `get_color()`, etc.

### Admin Verbs (`zone_admin.dm`)
- **Zone Status** - Show current zone stats and layout info

## Integration Points

### Weapon Restrictions
Weapons check zones via `SSovermap_zones.weapons_allowed_at(src)`:
- `voidcrew/modules/ship_combat/missile_launcher.dm` - `can_fire()` proc
- `voidcrew/modules/ship_combat/laser_turret.dm` - `can_fire()` proc
- `voidcrew/modules/ship_combat/interdictor.dm` - `can_interdict()` proc

### Cross-Zone Targeting
Ships can target each other between Contested and Lawless zones, but Neutral zone blocks all targeting:
- `voidcrew/modules/ship_combat/combat_console.dm`:
  - `start_targeting()` - Blocks acquiring locks if either ship is in Neutral zone
  - `check_targeting_range()` - Cancels in-progress targeting if either ship enters Neutral zone
  - `check_attack_range()` - Exits attack mode if either ship enters Neutral zone
  - `ui_data()` - Sends zone info for each nearby ship so UI can show which are targetable
- Ships in Neutral zone show as disabled in the targeting list with tooltip explaining why

### UI Integration
Zone data sent to TGUI via `ui_data()`:
- `voidcrew/modules/shuttle/helm/_helm.dm` - Helm console (zone + status)
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
| `COMSIG_SHIP_SHIELDING_CHANGED` | Ship | `(old_level, new_level)` | Ship's radiation shielding upgraded |

## Solar Radiation System

Zones closer to the sun expose crew to solar radiation. Ships need research-unlocked shielding to protect their crew.

### Radiation Levels
| Zone | Radiation Level | Required Shielding |
|------|-----------------|-------------------|
| Neutral | None | None |
| Contested | Moderate (1 hit/tick) | Standard Shielding |
| Lawless | Heavy (2 hits/tick) | Heavy Shielding |

Note: Standard Shielding provides partial protection in Lawless zone (reduces from 2 hits to 1 hit).

### Shielding Research
Shielding is unlocked via the techweb research tree:

1. **Standard Radiation Shielding** (Tier 2, 80 pts)
   - Requires: Basic Shuttle Research
   - Protects crew from Contested zone radiation
   - Reduces Lawless zone radiation by half

2. **Heavy Radiation Shielding** (Tier 4, 160 pts)
   - Requires: Standard Radiation Shielding
   - Protects crew from Contested and Lawless zone radiation

### Auto-Upgrade System
When shielding research is completed, ALL ships linked to that techweb automatically receive the upgrade:
- R&D servers on ships auto-link when a disk is inserted
- Ships announce when shielding upgrades are applied
- Helm console shows current shielding level and radiation status

### Radiation Effects
Unshielded crew in radiation zones:
- Receive the `solar_radiation_exposure` component
- Take radiation damage every 5 seconds
- Can be protected by wearing radiation-resistant clothing (radsuits)
- Radiation stops when ship leaves zone or gains shielding

### Key Files
- `voidcrew/_DEFINES/overmap_zones.dm` - Radiation constants
- `voidcrew/modules/research/radiation_shielding_research.dm` - Research nodes
- `voidcrew/modules/overmap/code/modules/overmap/ship_radiation.dm` - Ship shielding procs
- `voidcrew/modules/overmap/code/modules/overmap/zones/zone_radiation.dm` - Radiation processing
- `voidcrew/modules/overmap/code/modules/overmap/zones/solar_radiation_component.dm` - Exposure component

## Future Hooks

The zone system is designed for expansion. Planned integrations:
- **Missions** - Higher payouts in dangerous zones
- **Planet weather** - Zone-based weather events
- **Mob spawns** - Different enemies per zone
- **Loot tables** - Better drops in Lawless zones
- **NPC ships** - Traders in Neutral, pirates in Lawless

## Configuration

Zone thresholds in `zone_controller.dm`:
```dm
// Inner ring (Lawless) - dangerous, close to sun
if(normalized < 0.33)
    return ZONE_RED

// Middle ring (Contested) - caution zone
if(normalized < 0.66)
    return ZONE_YELLOW

// Outer ring (Neutral) - safe, edge of map
return ZONE_GREEN
```

Zone transition time in `overmap_zones.dm`:
```dm
#define ZONE_TRANSITION_TIME (10 SECONDS)  // Time to cross zone boundaries
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
