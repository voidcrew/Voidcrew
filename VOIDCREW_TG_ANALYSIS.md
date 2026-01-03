# TG Station Systems Analysis for Voidcrew

## Overview
**Analysis Completed:** 2025-12-30
**Status:** COMPLETE - 20+ investigation agents deployed

This document provides a comprehensive comparison of TG Station systems vs Voidcrew implementations, identifying gaps, partial implementations, and Voidcrew-specific additions.

---

## Executive Summary

### Critical Gaps (NOT IMPLEMENTED)
| System | TG Files | Impact | Dev Hours Est. |
|--------|----------|--------|----------------|
| Dynamic Gamemode System | 9 files | No antagonist scaling | 300-400 |
| Random Events | 65+ events | No station events | 200-300 |
| Inter-Ship Communications | N/A | Ships can't radio each other | 40-60 |
| Engineering (SM/Tesla/Singularity) | 55+ files | Missing major power systems | 200+ |
| Atmospherics (Full LINDA) | 75+ files | No atmospheric simulation | 150+ |
| Cargo Bounties/Exports | 20+ files | No economy system | 80-120 |

### Complete Parity (FULLY IMPLEMENTED)
- Medical/Chemistry systems
- Service systems (food, hydroponics, fishing)
- AI/Silicon systems
- Combat/Weapons (99%+ parity)
- TGUI Interface system

### Voidcrew Replacements/Additions
- Overmap system (replaces TG shuttle system)
- Custom ship engines (electric, fuel, liquid, void)
- Ship construction system
- Helm console
- Survey/exploration system

---

## 1. GAMEMODE & DYNAMIC SYSTEMS

### Status: CRITICAL GAP

**TG Implementation:**
- Dynamic subsystem with 9 core files
- 5 threat tiers (Green -> High) based on population
- Ruleset framework with population-aware scaling
- 10+ roundstart rulesets
- 20+ midround rulesets (light/heavy)
- 5+ latejoin antagonist rulesets
- Cooldown-based injection system
- Admin control panel

**Voidcrew Status:**
- Only basic `game_mode.dm` with overmap jump completion check
- NO dynamic tier system
- NO ruleset evaluation
- NO population-aware antagonist scaling
- NO threat budget calculation
- NO midround/latejoin injection

**Key TG Files:**
```
code/controllers/subsystem/dynamic/
  - dynamic.dm (main controller)
  - _dynamic_ruleset.dm (base ruleset)
  - _dynamic_tier.dm (threat tiers)
  - dynamic_ruleset_roundstart.dm
  - dynamic_ruleset_midround.dm
  - dynamic_ruleset_latejoin.dm
  - dynamic_admin.dm (admin panel)
```

**Implementation Priority:** HIGH
**Estimated Hours:** 300-400

---

## 2. RANDOM EVENTS SYSTEM

### Status: CRITICAL GAP

**TG Implementation:** 65+ random events across categories:

| Category | Count | Examples |
|----------|-------|----------|
| Engineering | 8 | Electrical Storm, Grid Check, Supermatter Surge |
| Space | 8 | Meteors (3 variants), Carp Migration, Radiation Storm |
| Invasion | 7 | Grey Tide, Space Vines, Portal Storm |
| Health | 6 | Disease Outbreak, Brain Trauma, Heart Attack |
| Anomalies | 10 | Bluespace, Dimensional, Pyro, Gravitational |
| Economic | 5 | Market Crash, Stray Cargo, Shuttle Catastrophe |
| Wizard Mode | 24 | Summon Guns, Lava, Race Change |
| Holiday | 4 | Halloween, Christmas, Valentine, Easter |

**Voidcrew Status:**
- 0% implemented
- Only overmap-specific space hazards (asteroid storms, nebulae)
- NO `/datum/round_event` framework
- NO event scheduling subsystem (SSevents)
- NO admin event controls

**Key TG Files:**
```
code/modules/events/
  - _event.dm (base event datum)
  - anomaly/ (10 anomaly types)
  - ghost_role/ (sentience, operative)
  - wizard/ (24 wizard events)
  - holiday/ (4 holiday events)
code/controllers/subsystem/events.dm
```

**Implementation Priority:** MEDIUM-HIGH
**Estimated Hours:** 200-300

---

## 3. COMMUNICATION SYSTEMS

### Status: CRITICAL GAP FOR INTER-SHIP

**TG Communication Systems:**
| System | Purpose | Key File |
|--------|---------|----------|
| Radio Headsets | Personal crew comms | `code/game/objects/items/devices/radio/headset.dm` |
| Encryption Keys | Department channel access | `encryptionkey.dm` |
| Telecomms | Signal routing infrastructure | `code/game/machinery/telecomms/` |
| Telecomms Relay | Cross-Z-level transmission | `machines/relay.dm` |
| NTNet Relay | PDA/tablet network | `code/modules/NTNet/relays.dm` |
| PDA Messenger | Direct text messaging | `modular_computers/.../messenger/` |
| Priority Announce | Major announcements | `code/__HELPERS/priority_announce.dm` |

**Radio Frequencies:**
| Freq | Channel | Color |
|------|---------|-------|
| 1459 | Common | Green |
| 1359 | Security | Red |
| 1357 | Engineering | Orange |
| 1353 | Command | Gold |
| 1355 | Medical | Blue |

**Voidcrew Status:**
- Within same ship: WORKS (standard TG radio)
- Between ships: BROKEN (different Z-levels)

**What Voidcrew Has:**
1. `ship_announce()` - Crew-filtered announcements
2. `ship_broadcast_runechat()` - Visual floating text on overmap
3. Ship docking requests (30-second timeout)
4. Helm console messaging

**The Problem:**
```dm
// Ships are on different Z-levels with no shared ZTRAIT_STATION
// relay.dm line 28-33:
if(SSmapping.level_trait(relay_turf.z, ZTRAIT_STATION))
    for(var/z_level in SSmapping.levels_by_trait(ZTRAIT_STATION))
        signal.levels |= SSmapping.get_connected_levels(z_level)
```

**Missing Features:**
| Feature | Status |
|---------|--------|
| Inter-ship radio | NOT IMPLEMENTED |
| Fleet-wide channel | NOT IMPLEMENTED |
| Ship hailing | PARTIAL (docking only) |
| Emergency distress beacon | NOT IMPLEMENTED |
| Overmap chat | NOT IMPLEMENTED |

**Implementation Priority:** HIGH
**Estimated Hours:** 40-60

---

## 4. POWER SYSTEMS

### Status: PARTIALLY IMPLEMENTED

**TG Power Generation (8 systems):**
1. **Supermatter Engine** - Main station power, gas-based, delamination mechanics
2. **Singularity Engine** - Gravitational power, stage-based growth
3. **Tesla Engine** - Energy ball + coil system
4. **Turbine** - Gas-powered with modular parts
5. **Thermoelectric Generator (TEG)** - Heat differential
6. **PACMAN Generator** - Plasma/uranium fuel
7. **Solar Panels** - Renewable, sun tracking
8. **RTG** - Passive nuclear

**TG Power Storage:**
- SMES (multiple variants including Ship)
- Portable SMES
- Power Cells (500J to 40kJ+)

**TG Power Distribution:**
- APC (Area Power Controller) - 3 channels per area
- Power Cables (3 layers)
- Powernets

**Voidcrew Modifications:**
1. **PACMAN tweaks** (`voidcrew/modules/power/port_gen.dm`)
   - Extended fuel duration (260 vs 180 time_per_sheet)
   - Better part scaling

2. **Ship Engines** (`voidcrew/modules/shuttle/engine/`)
   - Ion Thruster (draws 50,000 kJ per burn from powernet)
   - Fuel/Liquid/Void engine variants

3. **Ship SMES** - Pre-charged to 20x standard

**NOT IMPLEMENTED:**
- Nuclear/Fusion reactors
- Ship-specific solar panels
- Power transfer between docked ships
- Unified ship power budget display
- Ship systems power consumption (shields, weapons, sensors)

**Key File Locations:**
```
TG: code/modules/power/
  - supermatter/, singularity/, tesla/, turbine/
  - smes.dm, cable.dm, apc/

Voidcrew: voidcrew/modules/power/
  - port_gen.dm

Ship Engines: voidcrew/modules/shuttle/engine/
  - electric.dm, fuel.dm, liquid.dm, void.dm
```

---

## 5. ENGINEERING SYSTEMS

### Status: CRITICAL GAP

**TG Engineering (204 files total):**

| System | Files | Status |
|--------|-------|--------|
| Power Generation | 55 | MINIMAL (only PACMAN tweaks) |
| Atmospherics (LINDA) | 75 | NOT IMPLEMENTED |
| Shuttle System | 41 | REPLACED (custom Voidcrew) |
| RCD System | 9 variants | NOT IMPLEMENTED |
| Disposal | 10 | INHERITED |
| Station Goals | 6 | INHERITED |

**Critical Missing Systems:**

1. **Supermatter Engine** (20+ files)
   - Core power generation
   - Delamination cascade mechanics
   - Gas-based behaviors

2. **Atmospherics LINDA** (75 files)
   - Environmental simulation
   - Gas mixture chemistry
   - Piping infrastructure (smart pipes, heat exchange)
   - All atmospheric devices (pumps, scrubbers, valves)
   - Air alarm system
   - HFR Fusion Reactor

3. **RCD System** (9 device variants)
   - Rapid Construction Device
   - Rapid Pipe Dispenser (RPD)
   - Rapid Turf Designer
   - Rapid Wiring Device
   - Design modes and memory system

**Voidcrew Replacements:**
- Custom shuttle construction system
- Ship engine variants (instead of TG shuttle)
- Custom helm console

**Implementation Priority:** MEDIUM-HIGH
**Estimated Hours:** 200-250 for full restoration

---

## 6. ANTAGONIST SYSTEMS

### Status: MOSTLY IMPLEMENTED

**TG Antagonists:** 46 types in `code/modules/antagonists/`

**Voidcrew Status:** 3 custom implementations
- Blob (with blob_mobs.dm)
- Crewmember template
- Cult (partial - bastard sword)

**Implementation Note:** TG antagonist datums are inherited - the gap is in the DYNAMIC SELECTION system, not the antagonist code itself.

---

## 7. CARGO/MINING SYSTEMS

### Status: SIGNIFICANT GAPS

**TG Cargo Systems:**
| System | Status |
|--------|--------|
| Bounty System | NOT IMPLEMENTED |
| Export System | NOT IMPLEMENTED |
| Mining Fauna (50+ types) | INHERITED but unused |
| Lavaland Ruins | INHERITED |
| Shipping/Receiving | BASIC |

**Missing Economic Features:**
- Bounty boards and contracts
- Export value tracking
- Station budget management
- Dynamic pricing

---

## 8. SCIENCE SYSTEMS

### Status: PARTIAL

**TG Science Modules:**
- Xenobiology (slimes, cores)
- Genetics
- Robotics (MODsuits, cyborgs)
- Nanites
- Research nodes/techweb
- Anomalies

**Voidcrew Status:**
- ~80% smaller science footprint
- Many systems inherited but may not be mapped/accessible
- Missing: Nanites control, some advanced research paths

---

## 9. MEDICAL/CHEMISTRY

### Status: COMPLETE PARITY

**Fully Inherited from TG:**
- Surgery system (all procedures)
- Wound/trauma system
- Chemistry/reagent reactions
- Disease system
- Organ system
- Cloning
- Medical machinery (sleepers, scanners, etc.)

---

## 10. SERVICE SYSTEMS

### Status: COMPLETE PARITY

**Fully Inherited:**
- Food/Cooking (all recipes)
- Hydroponics (plants, seeds, mutations)
- Fishing system
- Bartending
- Janitorial

---

## 11. AI/SILICON SYSTEMS

### Status: COMPLETE PARITY

**Fully Inherited:**
- AI core and laws
- Cyborg system
- pAI (personal AI)
- Law management
- AI camera network

---

## 12. COMBAT/WEAPONS

### Status: 99%+ PARITY

**Inherited with Enhancements:**
- All TG weapons
- All projectile types
- Martial arts (including Voidcrew's "Jungle Arts")
- Melee combat

**Voidcrew Addition:**
- Jungle Arts martial art style

---

## 13. SPECIES/RACES

### Status: PARTIAL

**TG Species:** 15+ playable species

**Missing from Voidcrew (8 species):**
1. Mushroom People
2. Snail People
3. Dullahan
4. Vampire (as species)
5. Podpeople variants
6. And 3+ more

---

## 14. SHUTTLE SYSTEMS

### Status: COMPLETELY REPLACED

**TG Shuttle System:**
- Emergency shuttle
- Supply shuttle
- Arrival shuttle
- Multiple variants (assault, infiltrator, etc.)
- Navigation computer
- Shuttle events (meteors, carp, turbulence)

**Voidcrew Replacement:**
- Overmap system for ship navigation
- Custom ship engines (electric, fuel, liquid, void)
- Helm console
- Ship construction system
- Survey/exploration
- Ship parts customization

**Key Voidcrew Files:**
```
voidcrew/modules/overmap/
  - code/modules/overmap/ship.dm
  - code/modules/overmap/events.dm

voidcrew/modules/shuttle/
  - helm/_helm.dm
  - engine/ (4 engine types)
  - construction/
  - survey/
  - ship_parts/
```

---

## 15. UI/INTERFACE (TGUI)

### Status: COMPLETE PARITY + ADDITIONS

**Inherited:** Full TGUI system (React/TypeScript)

**Voidcrew Additions:**
- ShipCatalog UI
- VoidcrewStore UI
- Helm Console UI
- Survey Computer UI

---

## 16. STATUS EFFECTS/MOB SYSTEMS

### Status: PARTIAL GAP

**TG Status Effects:** 65+ files in `code/datums/status_effects/`

**Categories:**
- Debuffs (stuns, knockdowns, slows)
- Buffs (speed, strength)
- Agent-specific effects
- Food effects
- Drug effects

**Voidcrew Status:**
- Framework largely inherited
- Some effects may not trigger due to missing event/antagonist systems

---

## 17. SUBSYSTEMS

### Status: MOSTLY INHERITED

**TG Subsystems:** 95+ in `code/controllers/subsystem/`

**Critical for Voidcrew:**
- SSovermap (Voidcrew custom)
- SSshuttle (modified)
- SSmapping (inherited)
- SSair (inherited)
- SSpower (inherited)

---

## Implementation Priority Matrix

### Phase 1: Critical (Immediate Impact)
| System | Hours | Impact |
|--------|-------|--------|
| Inter-Ship Communication | 40-60 | Ships can talk to each other |
| Dynamic Gamemode (basic) | 100-150 | Antagonist selection works |
| Basic Random Events | 50-80 | Station variety |

### Phase 2: High (Core Experience)
| System | Hours | Impact |
|--------|-------|--------|
| Midround Antagonist Injection | 80-100 | Round variety |
| Cargo Bounty System | 40-60 | Economic gameplay |
| Additional Antagonist Types | 20-40 | More antag variety |

### Phase 3: Medium (Polish)
| System | Hours | Impact |
|--------|-------|--------|
| Full Event System | 100-150 | Station chaos |
| Engineering (SM engine) | 80-100 | Advanced power |
| Missing Species | 20-40 | Character variety |

### Phase 4: Long-term
| System | Hours | Impact |
|--------|-------|--------|
| Full Atmospherics | 150+ | Realistic atmos |
| RCD System | 30-50 | Construction tools |
| Admin Dynamic Panel | 30-40 | Admin QoL |

---

## Key File Locations Reference

### TG Base Paths
```
code/modules/antagonists/     - 46 antagonist types
code/modules/events/          - 65+ random events
code/modules/power/           - 55 power files
code/modules/atmospherics/    - 75 atmos files
code/modules/shuttle/         - 41 shuttle files
code/controllers/subsystem/dynamic/ - Dynamic gamemode
code/game/machinery/telecomms/ - Radio/comms
```

### Voidcrew Paths
```
voidcrew/modules/overmap/     - Ship/overmap system
voidcrew/modules/shuttle/     - Custom engines, helm, construction
voidcrew/modules/power/       - PACMAN modifications
voidcrew/modules/antagonist/  - 3 custom antag types
voidcrew/edits/               - TG overrides
```

---

## Summary Statistics

| Category | TG Systems | Voidcrew Status | Gap % |
|----------|------------|-----------------|-------|
| Gamemodes/Dynamic | Complete | None | 100% |
| Random Events | 65+ | 0 | 100% |
| Inter-Ship Comms | N/A | None | 100% |
| Power Generation | 8 systems | 1 modified | 85% |
| Atmospherics | Complete | Inherited | 0%* |
| Antagonists | 46 types | 3 custom | 93%** |
| Cargo Economy | Complete | Basic | 70% |
| Medical/Chemistry | Complete | Complete | 0% |
| Service | Complete | Complete | 0% |
| AI/Silicon | Complete | Complete | 0% |
| Combat | Complete | Complete+ | 0% |
| Shuttle | Complete | Replaced | N/A |

*Inherited from TG but not actively used in ship context
**Antagonist datums inherited, selection system missing

---

## Recommendations

### Immediate Actions
1. Implement basic inter-ship radio using fleet frequency concept
2. Port dynamic gamemode tier system (simplified)
3. Add 5-10 essential random events

### Short-term Goals
1. Cargo bounty system for ship economy
2. Midround antagonist injection
3. Fleet communication channel

### Long-term Vision
1. Full dynamic gamemode parity
2. Ship-specific engineering challenges
3. Complete event variety
4. Multi-ship coordinated antagonists

---

*Document generated by parallel agent investigation. Last updated: 2025-12-30*
