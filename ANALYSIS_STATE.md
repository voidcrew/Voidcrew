# Analysis State Tracker

This file tracks the current state of the analysis so it can be resumed if context is lost.

## Current Phase
**Phase 2:** Agents running investigations

## Active Agents (as of 2025-12-30)
| Agent ID | Category | Status |
|----------|----------|--------|
| adbf36a | Antagonists | RUNNING |
| aa82fc4 | Gamemodes/Dynamic | RUNNING |
| a70c65f | Subsystems | RUNNING |
| a8a7bb1 | Modules A-H | RUNNING |
| a9c9c05 | Modules I-P | RUNNING |
| ab84fae | Modules Q-Z | RUNNING |
| ab4e64a | Events System | RUNNING |
| a483269 | Datums | RUNNING |
| a171cd0 | Mobs/Species | RUNNING |
| a03223e | Jobs/Roles | RUNNING |
| a20114d | Radio/Comms | RUNNING |
| a1ae3ae | Camera/AI/Silicon | RUNNING |
| ade7108 | Crafting/Construction | RUNNING |
| aa9112b | Medical/Surgery | RUNNING |
| ae16d56 | Power Systems | RUNNING |
| a32c3bd | Atmospherics | RUNNING |
| a5c882a | Items/Equipment | RUNNING |
| a535668 | Shuttle/Docking | RUNNING |
| af6078a | Admin Tools | RUNNING |
| a9c8f83 | Overmap | RUNNING |

## All Agents Launched - 20 Total
Categories covered:
- Antagonists, Gamemodes, Subsystems
- Modules (A-H, I-P, Q-Z), Events
- Datums, Mobs/Species, Jobs
- Radio/Comms, Camera/AI/Silicon
- Crafting, Medical, Power, Atmos
- Items, Shuttles, Admin, Overmap

## Agent Output Files
Agents write to: `C:\Users\isaac\AppData\Local\Temp\claude\C--Users-isaac-code\tasks\{agentId}.output`

## How to Resume
1. Check which agents completed by reading their output files
2. Read ANALYSIS_STATE.md for current state
3. Continue with remaining categories
4. Compile final VOIDCREW_TG_ANALYSIS.md

---

## COMPLETED AGENT RESULTS
(Results will be appended below as agents complete)

---

### RADIO/COMMUNICATIONS ANALYSIS
**Agent:** Communications (a20114d)
**Status:** Complete
**Date:** 2025-12-30

#### TG COMMUNICATION SYSTEMS:

| System | Purpose | How it works | Key Files |
|--------|---------|--------------|-----------|
| **Radio Headsets** | Personal crew comms | Subspace transmission via telecomms, encryption keys grant channel access | `code/game/objects/items/devices/radio/headset.dm` |
| **Encryption Keys** | Department channel access | Keys define which frequencies headset can access (Security, Engineering, etc.) | `code/game/objects/items/devices/radio/encryptionkey.dm` |
| **Telecomms System** | Signal routing infrastructure | Receiver -> Bus -> Server -> Hub -> Relay -> Broadcaster chain processes signals | `code/game/machinery/telecomms/` |
| **Telecomms Relay** | Cross-Z-level transmission | Adds Z-levels to signal's reach, uses `ZTRAIT_STATION` for station levels | `code/game/machinery/telecomms/machines/relay.dm` |
| **Telecomms Hub** | Central routing | Routes signals between receivers, buses, servers, relays, and broadcasters | `code/game/machinery/telecomms/machines/hub.dm` |
| **Station Bounced Radio** | Basic handheld radio | Non-subspace backup transmission when telecomms fails | `code/game/objects/items/devices/radio/radio.dm` |
| **Intercom** | Fixed wall radio | Area-powered, can be tuned to various frequencies | `code/game/objects/items/devices/radio/intercom.dm` |
| **NTNet Relay** | Network for modular computers | Global quantum relay network for PDAs/tablets, DoS vulnerable | `code/modules/NTNet/relays.dm` |
| **PDA Messenger** | Direct text messaging | Uses `GLOB.pda_messengers` registry, routes through telecomms message server | `code/modules/modular_computers/file_system/programs/messenger/messenger_program.dm` |
| **Priority Announce** | Major announcements | Sends to player list (can filter by mob list), plays sound | `code/__HELPERS/priority_announce.dm` |
| **SSradio** | Radio frequency subsystem | Maintains frequency -> device mappings, handles saymodes | `code/controllers/subsystem/networks/radio.dm` |

#### RADIO FREQUENCIES (from radio.dm):
| Frequency | Channel | Color |
|-----------|---------|-------|
| 1459 | Common | #1ecc43 (green) |
| 1359 | Security | #dd3535 (red) |
| 1357 | Engineering | #f37746 (orange) |
| 1353 | Command | #fcdf03 (gold) |
| 1355 | Medical | #57b8f0 (blue) |
| 1351 | Science | #c68cfa (purple) |
| 1347 | Supply | #b88646 (brown) |
| 1349 | Service | #6ca729 (green) |
| 1337 | CentCom | #2681a5 (teal) |
| 1213 | Syndicate | #8f4a4b (dark red) |

#### TRANSMISSION METHODS:
1. **TRANSMISSION_RADIO (1)** - Basic electromagnetic (backup when telecomms down)
2. **TRANSMISSION_SUBSPACE (2)** - Requires telecomms infrastructure (headsets)
3. **TRANSMISSION_SUPERSPACE (3)** - CentCom independent radios only

#### VOIDCREW STATUS:

**IMPLEMENTED SHIP COMMUNICATIONS:**

1. **Ship Announcements** (`voidcrew/modules/overmap/code/modules/overmap/ship.dm` line 290-299):
   - `ship_announce(message, title, must_be_same_z_level, sound)` proc
   - Uses `priority_announce()` with filtered player list (ship_team.members only)
   - Only crew on the ship's team receive announcements

2. **Ship Runechat Broadcast** (`ship.dm` line 305-321):
   - `ship_broadcast_runechat(message)` - Visual floating text above ship on overmap
   - Used by helm console for quick messages

3. **Ship-to-Ship Docking Communication** (`ship.dm` line 874-931):
   - Ships can send docking requests to each other
   - Both ships receive announcements about docking status
   - 30-second timeout on docking requests

4. **Helm Console Messaging** (`voidcrew/modules/shuttle/helm/_helm.dm` line 374-380):
   - Helm can broadcast short messages visible on overmap

**KEY VOIDCREW SHIP TEAM SYSTEM:**
- Each ship has a `datum/team/voidcrew/ship_team`
- Crew registered via `ship_team.add_member(crewmate.mind)`
- Announcements filtered to `ship_team.members`

#### SHIP COMMUNICATION CHALLENGES:

**PROBLEM: Ships are on different Z-levels**
- TG telecomms uses `ZTRAIT_STATION` to define which Z-levels connect
- Ships are on separate map zones with no shared Z-trait
- Telecomms relays check: `SSmapping.level_trait(relay_turf.z, ZTRAIT_STATION)`
- Standard radio transmission uses: `SSmapping.get_connected_levels(get_turf(source))`

**CURRENT LIMITATIONS:**
1. **Headset Radio**: Only works within same connected Z-levels (single ship)
2. **PDA Messaging**: Uses `GLOB.pda_messengers` which is global, BUT signal routing goes through telecomms which may be Z-restricted
3. **Announcements**: Already work cross-ship via `priority_announce(players = ...)` filtering

**CAN SHIPS COMMUNICATE?**
- **Within same ship**: YES - standard radio/telecomms works
- **Between different ships**: LIMITED
  - Ship announcements: Work only for own crew
  - Docking requests: Work between ships on same overmap tile
  - Radio: NO - different Z-levels not connected
  - PDA: MAYBE - depends on telecomms message server routing

**POTENTIAL SOLUTIONS FOR INTER-SHIP COMMS:**

1. **Fleet Frequency Approach**:
   - Add new frequency (e.g., `FREQ_FLEET`) at fleet-wide telecomms level
   - Require ships to have "fleet relay" machinery
   - Similar to how CentCom uses `TRANSMISSION_SUPERSPACE`

2. **Overmap Relay System**:
   - Ships on same overmap tile could share communications
   - Implement "hailing frequency" for ships to contact each other
   - Docked ships already share Z-level (empty space encounter)

3. **Long-Range Communication Console**:
   - Dedicated machine for inter-ship messages
   - Could use existing PDA messenger infrastructure
   - Bypass telecomms Z-level restrictions

4. **Subspace Beacon Network**:
   - Fleet-wide beacon that links ship relays
   - Similar to how syndicate radios hear all frequencies

#### NOT IMPLEMENTED (MISSING FEATURES):

| Feature | Status | Notes |
|---------|--------|-------|
| Inter-ship radio | NOT IMPLEMENTED | Ships can't hear each other's radio |
| Fleet-wide channel | NOT IMPLEMENTED | No fleet command frequency |
| Ship hailing system | PARTIAL | Only docking requests exist |
| Cross-ship PDA | UNCLEAR | May work if telecomms bypassed |
| Emergency distress beacon | NOT IMPLEMENTED | No SOS broadcast system |
| Overmap chat | NOT IMPLEMENTED | Ships can't broadcast on overmap |

#### KEY CODE PATHS:

**Radio transmission flow:**
1. `radio.dm:talk_into_impl()` - Initial message handling
2. `broadcasting.dm:send_to_receivers()` - Signal to telecomms
3. `receiver.dm` -> `bus.dm` -> `server.dm` -> `hub.dm` -> `relay.dm` -> `broadcaster.dm`
4. `broadcasting.dm:broadcast()` - Final delivery to `GLOB.all_radios[frequency]`

**Z-level check in relay (relay.dm line 28-33):**
```dm
if(SSmapping.level_trait(relay_turf.z, ZTRAIT_STATION))
    for(var/z_level in SSmapping.levels_by_trait(ZTRAIT_STATION))
        signal.levels |= SSmapping.get_connected_levels(z_level)
```

**Ship announcement filtering (ship.dm line 290-299):**
```dm
/obj/structure/overmap/ship/proc/ship_announce(message, title, must_be_same_z_level, sound)
    var/list/announce_targets = list()
    for(var/datum/mind/shipmate as anything in ship_team.members)
        var/mob/crewmate = shipmate.current
        if(!crewmate) continue
        if(must_be_same_z_level && crewmate.z != z) continue
        announce_targets += crewmate
    priority_announce(message, title, sound, players = announce_targets)
```

#### KEY FILES:
```
TG Radio System:
- code/game/objects/items/devices/radio/radio.dm (base radio)
- code/game/objects/items/devices/radio/headset.dm (headsets)
- code/game/objects/items/devices/radio/encryptionkey.dm (encryption)
- code/game/objects/items/devices/radio/intercom.dm (wall intercoms)
- code/__DEFINES/radio.dm (frequencies, channels)
- code/game/communications.dm (radio frequency management)
- code/controllers/subsystem/networks/radio.dm (SSradio)

TG Telecomms:
- code/game/machinery/telecomms/telecomunications.dm (base machinery)
- code/game/machinery/telecomms/broadcasting.dm (signal/subspace/vocal)
- code/game/machinery/telecomms/machines/relay.dm (Z-level linking)
- code/game/machinery/telecomms/machines/hub.dm (central routing)
- code/game/machinery/telecomms/machines/server.dm (logging/processing)

TG Messaging:
- code/modules/modular_computers/file_system/programs/messenger/ (PDA messenger)
- code/modules/NTNet/relays.dm (NTNet quantum relay)
- code/__HELPERS/priority_announce.dm (announcements)

Voidcrew Ship Comms:
- voidcrew/modules/overmap/code/modules/overmap/ship.dm (ship_announce)
- voidcrew/modules/shuttle/helm/_helm.dm (helm messaging)
```

#### RECOMMENDATIONS FOR VOIDCREW:

1. **Short-term**: Use `priority_announce(players = fleet_members)` for fleet-wide announcements
2. **Medium-term**: Add fleet radio channel with `RADIO_SPECIAL_FLEET` flag
3. **Long-term**: Implement full inter-ship telecomms with relay machinery

---

### CRAFTING/CONSTRUCTION ANALYSIS
**Agent:** Crafting
**Status:** Complete
**Date:** 2025-12-30

#### TG CRAFTING SYSTEMS:
| System | Purpose | Complexity | Location |
|--------|---------|------------|----------|
| Personal Crafting | Player crafting menu UI | High | `code/datums/components/crafting/crafting.dm` |
| Slapcrafting | Quick crafting by hitting items together | Medium | `code/datums/elements/slapcrafting.dm` |
| Gun Crafting | Specialized weapon assembly | Medium | `code/datums/components/crafting/guncrafting.dm` |
| Cooking | Food preparation recipes | High | `code/modules/food_and_drinks/recipes/` |
| Manufactorio | Factory automation crafting | High | `code/modules/manufactorio/` |

#### CRAFTING CATEGORIES (21 Food + 18 General):
**Food Categories:**
- Foods, Breads, Burgers, Cakes, Egg-Based, Lizard Food, Meats, Seafood
- Martian, Misc Food, Mexican, Moth Food, Pastries, Pies, Pizzas
- Salads, Sandwiches, Soups, Spaghettis, Frozen, Drinks

**Crafting Categories:**
- Weapons Ranged, Weapons Melee, Weapon Ammo, Robotics, Misc
- Clothing, Chemistry, Atmospherics, Structures, Tiles, Windows
- Doors, Furniture, Equipment, Containers, Entertainment, Tools, Blood Cult

#### CONSTRUCTION MECHANICS:
| System | Purpose | Location |
|--------|---------|----------|
| Construction Component | Step-by-step building with tools | `code/datums/components/construction.dm` |
| Constructable Frame | Machine frame assembly | `code/game/machinery/constructable_frame.dm` |
| RCD (Rapid Construction Device) | Instant wall/floor building | `code/game/objects/items/rcd/RCD.dm` |
| RCL (Rapid Cable Layer) | Cable laying device | `code/game/objects/items/rcd/RCL.dm` |
| RPD (Rapid Pipe Dispenser) | Pipe construction | `code/game/objects/items/rcd/RPD.dm` |
| RTD (Rapid Transit Device) | Transit tube building | `code/game/objects/items/rcd/RTD.dm` |
| RWD (Rapid Window Device) | Window installation | `code/game/objects/items/rcd/RWD.dm` |
| RLD (Rapid Light Device) | Light fixture placement | `code/game/objects/items/rcd/RLD.dm` |
| RPLD (Rapid Plant Device) | Plant bed placement | `code/game/objects/items/rcd/RPLD.dm` |
| RHD (Rapid Hydro Device) | Hydroponics construction | `code/game/objects/items/rcd/RHD.dm` |
| RSF (Rapid Scaffold Fabricator) | Scaffolding construction | `code/game/objects/items/rcd/RSF.dm` |

#### MATERIALS SYSTEM:
| Material | Special Properties | Tradable |
|----------|-------------------|----------|
| Iron | Base material, cheap | Yes |
| Glass | Transparent, fragile (0.1x integrity) | Yes |
| Silver | Anti-vampire potential | Yes |
| Gold | 1.2x force, shiny | Yes |
| Diamond | 1.25x integrity, rare | Yes |
| Uranium | Radioactive (structures only) | Yes |
| Plasma | Adds firestacks, combustible | No |
| Bluespace | Teleportation effects | Yes |
| Bananium | Honks, slippery | No |
| Titanium | 1.3x force, rust-resistant | Yes |
| Plastic | 0.85x force, cheap | No |
| Wood | Flammable, 0.5x force | No |
| Adamantine | 1.5x force, fire-resistant | No |
| Mythril | 1.2x force, fantasy enchantments | No |
| Hot Ice | Releases plasma when heated | No |
| Metal Hydrogen | Extreme pressure creation | No |
| Runite | Anti-magic, 1.3x force | No |
| Zaukerite | Light-absorbing, laser-resistant | No |

Materials Location: `code/datums/materials/`

#### WIREMOD SYSTEM:
Wiremod is a programmable circuit system allowing players to create custom logic.
Location: `code/modules/wiremod/`

| Component | Purpose |
|-----------|---------|
| Integrated Circuit | Main programmable board that holds components |
| Component Printer | Creates circuit components |
| USB Cable | Connects circuits to shells |
| Shells | Physical objects that contain circuits |

Features:
- Visual node-based programming UI
- Power cell requirements
- Component size limits
- Variable storage (getters/setters)
- Admin-only circuits for powerful effects
- Lock/unlock with ID cards

#### MANUFACTORIO SYSTEM:
Factory automation system for conveyor-based manufacturing.
Location: `code/modules/manufactorio/`

| Machine | Purpose |
|---------|---------|
| Crafter | Automated crafting of recipes |
| Crusher | Breaks down items |
| Lathe | Material processing |
| Router | Item distribution |
| Smelter | Ore processing |
| Sorter | Item filtering by type |
| Storage Box | Buffer storage |
| Unloader | Outputs items to conveyors |

Features:
- Power via cable network
- Conveyor belt integration (Bumped items intake)
- Recipe selection via multitool
- Cooking recipes support

#### STOCK PARTS & MACHINE CONSTRUCTION:
Location: `code/modules/research/stock_parts.dm`

Machine Construction Process:
1. Build a frame (5 iron sheets + wrench)
2. Install circuit board
3. Add required stock parts
4. Screwdriver to complete

Stock Part Types:
- Capacitors (power efficiency)
- Scanning Modules (accuracy)
- Manipulators (speed)
- Micro-Lasers (precision)
- Matter Bins (storage)
- Power Cells (energy storage)

#### VOIDCREW STATUS:
| Feature | Status | Notes |
|---------|--------|-------|
| Personal Crafting | INHERITED | Full TG system |
| Slapcrafting | INHERITED | Full TG system |
| Materials System | INHERITED | Full TG system |
| RCD | INHERITED | Full TG system |
| Wiremod | INHERITED | Full TG system |
| Manufactorio | INHERITED | Full TG system |
| Stock Parts | INHERITED | Full TG system |
| **Ship Construction Console** | VOIDCREW NEW | Custom ship building system |
| Ship Construction Drone | VOIDCREW NEW | Remote construction drone |
| Shuttle Expansion | VOIDCREW NEW | Dynamic shuttle resizing |
| Docking Port Relocation | VOIDCREW NEW | Move docking port to different airlocks |

#### VOIDCREW-SPECIFIC CONSTRUCTION:
Location: `voidcrew/modules/shuttle/construction/`

**Ship Construction Console** (`construction_console.dm`):
- Remote drone control for building
- RCD-based construction within shuttle areas
- Automatic shuttle expansion when building adjacent tiles
- Automatic shuttle shrinking when deconstructing
- Docking port relocation to different airlocks
- Ore silo resource link (bypasses account checks with SILICON_OVERRIDE)
- Dimension limits: 56 max long, 40 max short
- TGUI interface for management

**Ship Construction Drone** (`construction_drone.dm`):
- Camera-like remote eye for construction
- Movement restricted to shuttle + adjacent tiles
- Build actions tied to drone location

**Shuttle Construction Actions** (`construction_actions.dm`):
- Configure RCD mode
- Build structures
- Deconstruct structures

**Features unique to Voidcrew:**
- `expand_shuttle_to_turf()` - Adds tiles to shuttle area
- `clear_empty_shuttle_turfs()` - Removes empty areas
- `relocate_docking_port()` - Moves docking position
- `reset_fans()` - Manages airlock tiny fans
- Dimension checking for shuttle size limits

#### NOT IMPLEMENTED / MISSING:
| Feature | Notes |
|---------|-------|
| Ship Blueprint System | No pre-designed ship templates for construction |
| Material Recycler Integration | No automatic recycling during deconstruction |
| Construction Cost Display | UI doesn't show material costs before building |
| Multi-user Construction | Only one user can control drone at a time |
| Automated Shuttle Repair | No automatic damage repair system |

#### KEY FILES:
```
Crafting:
- code/datums/components/crafting/crafting.dm (main system)
- code/__DEFINES/crafting.dm (flags and categories)
- code/_globalvars/lists/crafting.dm (category lists)

Construction:
- code/datums/components/construction.dm (step-by-step construction)
- code/game/machinery/constructable_frame.dm (machine frames)
- code/game/objects/items/rcd/*.dm (RCD variants)

Materials:
- code/datums/materials/_material.dm (base datum)
- code/datums/materials/basemats.dm (iron, glass, plasma, etc.)
- code/datums/materials/alloys.dm (composite materials)

Wiremod:
- code/modules/wiremod/core/integrated_circuit.dm (main system)
- code/modules/wiremod/core/component.dm (base component)
- code/modules/wiremod/components/ (individual components)

Manufactorio:
- code/modules/manufactorio/_manufacturing.dm (base machinery)
- code/modules/manufactorio/machines/crafter.dm (auto-crafting)

Voidcrew:
- voidcrew/modules/shuttle/construction/construction_console.dm
- voidcrew/modules/shuttle/construction/construction_drone.dm
- voidcrew/modules/shuttle/construction/construction_actions.dm
```

---


### SUBSYSTEMS ANALYSIS
**Agent:** Subsystems
**Status:** Complete
**Date:** 2025-12-30

#### TG SUBSYSTEMS FOUND (95+ subsystems total)

**Location:** C:\Users\isaac\code\tg-voidcrew\code\controllers\subsystem
| Subsystem | Purpose | Voidcrew Status |
|-----------|---------|-----------------|
| achievements | Tracks player achievements in database | Unmodified |
| addiction | Manages addiction processing | Unmodified |
| admin_verbs | Admin verb management and loading | Unmodified |
| ai_controllers | AI behavior controller processing | Unmodified |
| ai_idle_controllers | Idle AI behavior processing | Unmodified |
| air | Atmospherics simulation (gas, pressure, pipenets) | Unmodified |
| ambience | Ambient sound playback | Unmodified |
| area_contents | Tracks area contents efficiently | Unmodified |
| asset_loading | Manages asset loading | Unmodified |
| assets | Asset caching system | Unmodified |
| atoms | Atom initialization system | Unmodified |
| augury | Ghost/dead mob effects and communication | Unmodified |
| ban_cache | Caches ban information | Unmodified |
| blackbox | Telemetry and round statistics | Unmodified |
| blood_drying | Blood drying processing | Unmodified |
| chat | Chat message processing | Unmodified |
| dbcore | Database core connection management | Unmodified |
| dcs | Datums/Components/Signals system | Unmodified |
| discord | Discord integration | Unmodified |
| disease | Disease spreading and processing | Unmodified |
| dynamic/* | Dynamic gamemode antagonist selection | Unmodified (but may need ship adaptation) |
| early_assets | Early asset loading | Unmodified |
| economy | Economy/money management | EDITED - Removes roundstart paychecks and budget pool |
| events | Random event scheduling and execution | Unmodified |
| explosions | Explosion processing queue | Unmodified |
| fluids | Fluid (water/etc) spreading | Unmodified |
| garbage | Garbage collection/qdel management | Unmodified |
| greyscale_previews | Greyscale sprite preview generation | Unmodified |
| icon_smooth | Icon smoothing queue | Unmodified |
| init_profiler | Init profiling | Unmodified |
| input | Input handling | Unmodified |
| ipintel | IP intelligence checks | Unmodified |
| job | Job assignment and management | EDITED - Skips standard job assignment, uses ship slots |
| lag_switch | Lag mitigation controls | Unmodified |
| library | Library book management | Unmodified |
| lighting | Lighting updates | Unmodified |
| lua | Lua scripting support | Unmodified |
| machines | Machine processing | Unmodified |
| map_vote | Map voting system | Unmodified |
| mapping | Map loading and z-level management | Unmodified |
| market | Black market system | Unmodified |
| materials | Material registry | Unmodified |
| minor_mapping | Mice spawning, satchel placement | EDITED - Disables satchel placement |
| mobs | Mob processing | Unmodified |
| moods | Mood system processing | Unmodified |
| mouse_entered | Mouse enter event handling | Unmodified |
| movement/* | Movement processing (AI, newtonian, etc) | Unmodified |
| networks/* | Network subsystems (radio, research, etc) | Unmodified |
| nightshift | Night shift lighting changes | Unmodified |
| npcpool | NPC AI processing | Unmodified |
| ore_generation | Mining ore regeneration | Unmodified |
| overlays | Overlay processing queue | Unmodified |
| pai | pAI processing | Unmodified |
| parallax | Parallax background effects | Unmodified |
| pathfinder | JPS pathfinding processing | Unmodified |
| persistence/* | Persistent data (engravings, tattoos, etc) | Unmodified |
| persistent_paintings | Persistent painting storage | Unmodified |
| ping | Player ping tracking | Unmodified |
| points_of_interest | POI tracking for observers | Unmodified |
| polling | Candidate polling (ghost roles) | Unmodified |
| processing/* | Various processing subsystems | station EDITED (see below) |
| profiler | Performance profiling | Unmodified |
| queuelinks | Queue management | Unmodified |
| radiation | Radiation processing | Unmodified |
| radioactive_nebula | Radioactive nebula effects | Unmodified |
| restaurant | Restaurant system | Unmodified |
| runechat | Runechat message display | Unmodified |
| security_level | Security level management | Unmodified |
| server_maint | Server maintenance | Unmodified |
| shuttle | Shuttle/docking management | Extended with Voidcrew ship creation |
| skills | Skill system processing | Unmodified |
| sound_loops | Sound loop processing | Unmodified |
| sounds | Sound playback | Unmodified |
| spatial_gridmap | Spatial grid for efficient lookups | Unmodified |
| speech_controller | Speech processing | Unmodified |
| sprite_accessories | Sprite accessory loading | Unmodified |
| statpanel | Statpanel updates | Unmodified |
| stickyban | Stickyban management | Unmodified |
| stock_market | Stock market simulation | Unmodified |
| sun | Sun effects | Unmodified |
| tcgsetup | Trading card game setup | Unmodified |
| tgui | TGUI interface management | Unmodified |
| throwing | Thrown object processing | Unmodified |
| ticker | Round state/timing management | EDITED - Complete character/job spawn rewrite |
| time_track | Time tracking | Unmodified |
| timer | Timer callback management | Unmodified |
| title | Title screen management | Unmodified |
| traitor | Traitor uplink system | Unmodified |
| transport | Tram/transport system | Unmodified |
| tts | Text-to-speech | Unmodified |
| tutorials | Tutorial system | Unmodified |
| unplanned_* | Unplanned processing | Unmodified |
| verb_manager | Verb management | Unmodified |
| vis_overlays | Vis overlay processing | Unmodified |
| vote | Voting system | Unmodified |
| wardrobe | Wardrobe/clothing system | Unmodified |
| weather | Weather effects (ash storms, etc) | Unmodified |

#### VOIDCREW-SPECIFIC SUBSYSTEMS

| Subsystem | Location | Purpose |
|-----------|----------|---------|
| overmap | voidcrew/modules/overmap/code/controllers/subsystem/overmap.dm | Ship-based overmap, manages ships, planets, events, bluespace jumps |
| shuttle (extended) | voidcrew/modules/overmap/code/controllers/subsystem/shuttle.dm | Adds create_ship() proc for dynamic ship spawning |
| nanites | voidcrew/modules/nanites/code/nanites_subsystem.dm | Nanite cloud backup and processing |

#### VOIDCREW SUBSYSTEM EDITS (5 files)

1. **economy.dm** - Removes roundstart_paychecks and budget_pool, adds export/import tracking
2. **job.dm** - Skips standard TG job assignment, uses ship-based job slots
3. **minor_mapping.dm** - Disables satchel placement (no station maintenance)
4. **station.dm** - Disables station traits (not applicable to ships)
5. **ticker.dm** - Rewrites create_characters() for ship-based job assignment

#### KEY OBSERVATIONS

1. SSovermap is central to Voidcrew - Manages all ships, planets, events, bluespace jumps
2. Job system completely overhauled - Uses ship-based job slots and category preferences
3. Economy simplified - No department budgets, focuses on import/export tracking
4. Station traits disabled - Would cause issues with ship-based gameplay
5. Shuttle subsystem extended - create_ship() allows dynamic ship spawning
6. Most subsystems unchanged - Core systems (air, lighting, garbage, etc.) work as-is

---


### POWER SYSTEMS ANALYSIS
**Agent:** Power (ae16d56)
**Status:** Complete
**Completed:** 2025-12-30

#### TG POWER SYSTEMS:

**POWER GENERATION:**

1. **Supermatter Engine** (`code/modules/power/supermatter/`)
   - Main power source for most stations
   - Crystal-based power generation via gas absorption
   - Supports multiple gas types for different behaviors
   - Delamination system with various failure modes (explosive, cascade, etc.)
   - Full TGUI monitoring integration
   - Files: `supermatter.dm`, `supermatter_gas.dm`, `supermatter_delamination/`, `supermatter_variants.dm`

2. **Singularity Engine** (`code/modules/power/singularity/`)
   - Gravitational singularity power generation
   - Stage-based growth (1-6)
   - Containment field system
   - Files: `singularity.dm`, `containment_field.dm`, `emitter.dm`, `field_generator.dm`

3. **Tesla Engine** (`code/modules/power/tesla/`)
   - Energy ball power generator
   - Zaps coils for power generation
   - Mini-ball orbital system
   - Files: `energy_ball.dm`, `coil.dm`

4. **Turbine** (`code/modules/power/turbine/`)
   - Gas-powered turbine generator
   - Uses temperature/pressure differentials
   - Modular parts system with tiered upgrades
   - Computer control interface
   - Files: `turbine.dm`, `turbine_computer.dm`, `turbine_parts.dm`

5. **Thermoelectric Generator (TEG)** (`code/modules/power/thermoelectric_generator.dm`)
   - Heat differential power generation
   - Requires hot and cold circulators
   - 65% efficiency by default
   - TGUI interface

6. **PACMAN Portable Generator** (`code/modules/power/port_gen.dm`)
   - Fuel-based portable power
   - Uses plasma sheets (default) or uranium (S.U.P.E.R. variant)
   - Adjustable power output (1-4x, or unlimited if emagged)
   - Heat management/explosion risk

7. **Solar Panels** (`code/modules/power/solar.dm`)
   - Renewable power source
   - Sun tracking via solar tracker/computer
   - 2500W base generation rate
   - Multiple glass tiers affect power output

8. **RTG (Radioisotope Thermoelectric Generator)** (`code/modules/power/rtg.dm`)
   - Passive nuclear power
   - 1000W base, scales with parts
   - Variants: Standard, Advanced, Abductor (Void Core), Lavaland, Debug, Old Station

**POWER STORAGE:**

1. **SMES** (`code/modules/power/smes.dm`)
   - Primary power storage
   - Configurable input/output levels (max 200kW base)
   - Terminal-based connection
   - Variants: Standard, Super, Full, Ship, Engineering, Magical

2. **Portable SMES** (`code/modules/power/smes_portable.dm`)
   - Connector + Portable Bank system
   - Mobile power storage
   - Dockable to SMES connectors

3. **Power Cells** (`code/modules/power/cell.dm`)
   - AA (500J), Upgraded (2.5kJ), High (10kJ), Super (20kJ), Hyper (30kJ), Bluespace (40kJ)
   - Special: Ninja, Crystal, Infinite, EMP-proof, Potato

4. **Batteries** (`code/modules/power/battery.dm`)
   - Machine-level power storage

**POWER DISTRIBUTION:**

1. **Area Power Controller (APC)** (`code/modules/power/apc/`)
   - One per area
   - Three channels: Lighting, Equipment, Environment
   - Auto-management based on charge level
   - Threshold-based channel shutoff (15%, 30%, 75%)
   - Terminal wire connection
   - Files: `apc_main.dm`, `apc_power_proc.dm`, `apc_attack.dm`, `apc_tool_act.dm`, etc.

2. **Power Cables** (`code/modules/power/cable.dm`)
   - Three cable layers (red, yellow, blue)
   - Multilayer cable hubs for layer interconnection
   - Multi-Z cable hubs for vertical connections
   - Node-based connection system

3. **Terminal** (`code/modules/power/terminal.dm`)
   - Connection point between cables and machines

4. **Powernet** (`code/modules/power/powernet.dm`)
   - Network management datum
   - Tracks available power, load, excess
   - Light flicker propagation on damage

**MONITORING & CONTROL:**

1. **Power Monitor** (`code/modules/power/monitor.dm`)
   - Station-wide power monitoring
   - Supply/demand graphs
   - Per-area breakdown

2. **Solar Control Computer** (in `solar.dm`)
   - Panel tracking control
   - Timed or auto tracking modes

3. **Turbine Computer** (`code/modules/power/turbine/turbine_computer.dm`)
   - Turbine control interface

**LIGHTING:**
- `code/modules/power/lighting/` - Light machinery, construction, items

**OTHER SYSTEMS:**
- **Gravity Generator** (`code/modules/power/gravitygenerator.dm`)
- **Energy Accumulator** (`code/modules/power/energy_accumulator.dm`)
- **Floodlight** (`code/modules/power/floodlight.dm`)
- **Tracker** (solar) (`code/modules/power/tracker.dm`)

#### VOIDCREW STATUS:
**What's Modified for Ships:**

1. **PACMAN Generator Modifications** (`voidcrew/modules/power/port_gen.dm`)
   - Extended time_per_sheet to 260 (from 180) for plasma variant
   - S.U.P.E.R. variant: 15kW power, 85 time_per_sheet
   - RefreshParts override with consumption coefficient calculation
   - Max sheets now scales with matter bin tier squared * 50

2. **Ship Engines Using Power System** (`voidcrew/modules/shuttle/engine/`)
   - **Ion Thruster (Electric)** (`electric.dm`):
     - Draws power from connected powernet
     - 50,000 kJ per burn
     - Engine power: 10
     - Checks SMES for fuel display
   - **Base Ship Engine** (`shuttle_engine.dm`):
     - Enable/disable functionality
     - Mass-based fuel consumption scaling
     - Thrust percentage system

3. **Ship SMES Variant**:
   - `/obj/machinery/power/smes/ship` - Pre-charged to 20x standard (20 * STANDARD_BATTERY_CHARGE)

#### NOT IMPLEMENTED:
**Missing/Unused Power Features in Voidcrew:**

1. **Nuclear Reactor** - No nuclear/fission reactor system found
2. **Fusion Reactor** - No fusion power implementation
3. **Ship-Specific Solar** - Standard solars, no ship-mounted variants
4. **Ship Battery Banks** - No dedicated ship battery array system beyond SMES
5. **Power Transfer Between Ships** - No docking power transfer mechanism found
6. **Ship Power Budget Display** - No unified ship power management UI
7. **Emergency Power Modes** - No ship-specific emergency power protocols
8. **Power Consumption by Ship Systems**:
   - Shields (if any) power draw
   - Weapons power draw
   - Sensor power draw
   - Life support dedicated power

**Partially Implemented:**
- Ion thrusters use powernet but rely on standard SMES infrastructure
- Ship helms reference power but mainly for engine systems
- No dedicated "ship reactor" - uses standard TG power generation

#### KEY FILE LOCATIONS:
```
TG Power Base: code/modules/power/
  - power.dm (base machinery class)
  - smes.dm (power storage)
  - cable.dm (distribution)
  - apc/ (area power controllers)
  - supermatter/ (main engine)
  - singularity/ (singulo engine)
  - tesla/ (tesla engine)
  - turbine/ (turbine engine)
  - solar.dm (solar panels)
  - port_gen.dm (PACMAN generators)
  - rtg.dm (radioisotope generators)
  - thermoelectric_generator.dm (TEG)
  - monitor.dm (power monitoring)
  - powernet.dm (network datum)
  - cell.dm (power cells)
  - lighting/ (lights)

Voidcrew Power: voidcrew/modules/power/
  - port_gen.dm (PACMAN modifications)

Ship Engines: voidcrew/modules/shuttle/engine/
  - shuttle_engine.dm (base ship engine)
  - electric.dm (ion thruster - uses power)
  - fuel.dm (fuel-based engines)
  - liquid.dm (liquid fuel engines)
  - void.dm (void engines)
```

---



### ADMIN TOOLS ANALYSIS
**Agent:** Admin
**Status:** Complete
**Date:** 2025-12-30

#### TG ADMIN SYSTEMS:

**1. Core Admin Infrastructure:**
- `/datum/admins` - Main admin datum with rank management, 2FA support, permissions
- `admin_verbs.dm` (809 lines) - Central admin verb definitions using ADMIN_VERB macro
- `holder2.dm` (516 lines) - Admin holder/datum management with rights checking
- `admin.dm` (170 lines) - Admin messaging and helper procs

**2. Admin Verbs/Commands (Major Categories):**
| Category | Verbs | File |
|----------|-------|------|
| Game Panel | Create Object/Turf/Mob, Duplicate Marked | `admin.dm` |
| Teleportation | Jump To Area/Turf/Mob/Coord/Key, Get/Send | `adminjump.dm` |
| Player Management | Player panel, FLW, VV, PP, PM, SM | `player_panel.dm` |
| Communication | Subtle/Headset/Direct/Local/Global Narrate | `adminevents.dm` |
| Spawn System | Spawn Atom, PodSpawn, Spawn Cargo | `admin.dm` |
| Explosions | Drop Bomb, DynEx Bomb, EMP | `admin_verbs.dm`, `adminfun.dm` |

**3. Variable Editing (View Variables):**
| File | Purpose |
|------|---------|
| `view_variables.dm` | Main VV panel with search, dropdown actions |
| `modify_variables.dm` | Edit, Change, Mass modify variables |
| `filterrific.dm` | Visual filter editor |
| `particle_editor.dm` | Particle system editor |
| `color_matrix_editor.dm` | Color matrix editing |
| `mark_datum.dm`, `tag_datum.dm` | Datum marking/tagging |

**4. Event Triggering (`force_event.dm`):**
TGUI-based panel with categories:
- AI, Anomalies, Bureaucratic, Engineering, Entities
- Friendly, Health, Holiday, Invasion, Janitorial, Space, Wizard
- Admin setup prompts for configurable events
- Announce toggle option

**5. Build Mode (`/code/modules/buildmode/buildmode.dm`):**
- Direction switching, mode switching
- Grid-based build options with preview
- Click intercept system
- Multiple buildmode modes

**6. Smite System (32 types):**
| Category | Smites |
|----------|--------|
| Destruction | Gib, Dust, Lightning, BSA, Rod, Supply Pod |
| Transformation | Become Object, Nugget, Petrify, Fat |
| Debuffs | Bloodless, Boneless, Brain Damage, Curse of Babel |
| Fun | Fireball, Cluwndice, Fake Bwoink, Immerse |
| Complex | Ghost Control, Imaginary Friend, Puzzgrid, Retcon |

**7. Shuttle Administration (`adminshuttle.dm`):**
- Change Shuttle Events
- Call/Cancel/Disable/Enable Shuttle
- Hostile Environment toggle
- Shuttle Manipulator panel
- Fly shuttle to any docking port

**8. Debug Tools (`debug.dm`, 1034 lines):**
| Tool | Purpose |
|------|---------|
| Del-All variants | Delete atoms by type (normal/force/hard) |
| Area Testing | Check areas for missing equipment |
| Direct Control | Assume/Give control of mobs |
| Diagnostics | Del Log, Init Log, Timer Sources, Runtimes |
| Profiling | Line profiling, Tracy integration |
| Instance Counting | Count atoms/datums by type |

**9. Antag Panel (`antag_panel.dm`):**
- View/add/remove antagonists by category
- Objective management (add/edit/delete/complete/announce)
- Uplink management (TC/Progression points)
- Common commands per antag type
- Mind-level administration

**10. Logging & Investigation (`admin_investigate.dm`):**
Investigation logs available:
- Access Changes, Atmos, Botany, Cargo, Crafting
- Deaths, Engine, Experimentor, Gravity, Hallucinations
- Hypertorus, Portal, Presents, Radiation, Records, Research, Wires

**11. Other Admin Systems:**
| File | Size | Purpose |
|------|------|---------|
| `sql_ban_system.dm` | 49KB | Database ban management |
| `sql_message_system.dm` | 34KB | Admin messages/notes |
| `permissionedit.dm` | 51KB | Permission editing panel |
| `poll_management.dm` | 31KB | Server polls |
| `stickyban.dm` | 17KB | Sticky ban system |
| `topic.dm` | 55KB | Href topic handling |

**12. Admin Rights System:**
```
R_ADMIN   - General admin
R_BAN     - Ban management
R_FUN     - Fun/event tools
R_DEBUG   - Debug tools
R_SPAWN   - Spawn permissions
R_SERVER  - Server management
R_STEALTH - Stealth mode
R_POLL    - Poll management
R_BUILD   - Build mode
```

#### VOIDCREW STATUS:

**ONLY ONE Voidcrew modification found in admin tools:**

Location: `code/modules/admin/verbs/shuttlepanel.dm` (lines 32-38)
```dm
//VOID EDIT [
if(istype(src, /obj/docking_port/mobile/voidcrew))
    var/obj/docking_port/mobile/voidcrew/dockingport = src
    dockingport.current_ship.destroy_ship(TRUE)
else
    jumpToNullSpace()
// ]
```
- When admin deletes a Voidcrew ship shuttle, it properly destroys the ship datum
- Uses `current_ship.destroy_ship(TRUE)` instead of `jumpToNullSpace()`
- Ensures proper cleanup of ship datum and associated data

**All other admin tools are UNMODIFIED from TG.**

#### SHIP-SPECIFIC NEEDS FOR MULTI-SHIP:

**1. Ship Management Panel Needed:**
| Feature | Purpose |
|---------|---------|
| Ship List | All active ships with crew counts |
| Ship Status | Power, atmos, damage, FTL status |
| Quick Teleport | Jump to ship bridges |
| Ownership Display | Ship faction/owner info |

**2. Per-Ship Admin Commands:**
| Command | Purpose |
|---------|---------|
| Jump to Ship | By name or faction |
| Get Ship Crew | Teleport all crew from ship |
| Send to Ship | Send player to specific ship |
| Ship Control | Destroy/spawn/transfer ships |

**3. Ship Event Targeting:**
- Target events to specific ships
- Multi-ship wide events
- Per-ship hostile environments
- Ship vs ship event coordination

**4. Ship-Specific Investigation Logs:**
- Per-ship death logs
- Per-ship atmos logs
- Inter-ship communication logs
- FTL travel history

**5. Ship Build Mode Enhancements:**
- Ship boundary awareness
- Ship-constrained building
- Quick ship repair tools
- Breach detection/repair

**6. Ship Economy Admin:**
- View ship finances
- Adjust ship resources
- Trade history viewing
- Cargo pod tracking per ship

**7. Crew Management Per Ship:**
- List crew by ship
- Ship role assignment
- Cross-ship player tracking
- Respawn to specific ships

**8. Overmap Admin Panel:**
- View all ships on overmap
- Teleport to overmap locations
- Spawn ships at coordinates
- View/modify encounters

#### KEY FILES:
```
Core Admin:
- code/modules/admin/admin_verbs.dm (main verbs)
- code/modules/admin/holder2.dm (admin datum)
- code/modules/admin/admin.dm (helpers)

View Variables:
- code/modules/admin/view_variables/*.dm

Verbs:
- code/modules/admin/verbs/adminjump.dm
- code/modules/admin/verbs/adminevents.dm
- code/modules/admin/verbs/adminfun.dm
- code/modules/admin/verbs/debug.dm

Panels:
- code/modules/admin/player_panel.dm
- code/modules/admin/antag_panel.dm
- code/modules/admin/force_event.dm

Voidcrew Modified:
- code/modules/admin/verbs/shuttlepanel.dm (ship deletion handling)
```

---

### ANTAGONISTS ANALYSIS
**Agent:** Antagonists
**Status:** Complete
**Date:** 2025-12-30

#### SUMMARY
TG Station has 46 antagonist types. Voidcrew has minimal modifications:
- **3 Voidcrew-specific modules:** blob (wasteland variants), cult (bastard sword), crewmember (ship teams)
- **1 edit file:** `_locate_weakpoint.dm` (adapts traitor objective to ship-based areas)

---

#### NOT IMPLEMENTED (Station-dependent systems needing significant work):

| Antagonist | Description | Ship-Based Feasibility |
|------------|-------------|------------------------|
| **abductor** | Alien team (scientist + agent) that abducts and experiments on crew | MEDIUM - Need mothership, could dock with target ships |
| **ashwalker** | Lavaland tribal lizards that sacrifice bodies to resurrect | LOW - Tied to Lavaland/mining dimension |
| **battlecruiser** | Syndicate warship crew with nuclear objective | HIGH - Perfect for ship combat |
| **fugitive** | Escaped prisoners hunted by hunters | MEDIUM - Could work between ships |
| **highlander** | PvP battle royale mode with swords and nuke disc | LOW - Needs station as arena |
| **malf_ai** | Malfunctioning AI with special powers and station control | LOW - Ship AI would need rework |
| **nukeop** | Nuclear operatives stealing disc to nuke station | MEDIUM - Could target specific ships |
| **clown_ops** | Honking variant of nukeops | MEDIUM - Same as nukeops |
| **pirate** | Space pirates demanding ransom | HIGH - Natural fit for ship setting |
| **revolution** | Crew uprising against heads of staff | LOW - Needs station hierarchy |
| **separatist** | Department nationalism event | LOW - Needs station departments |
| **space_dragon** | Giant dragon spawning carp rifts | MEDIUM - Could target ships in space |
| **wizard** | Federation wizard with spells | MEDIUM - Could teleport between ships |

---

#### PARTIALLY IMPLEMENTED (Modified/Edited):

| Antagonist | Voidcrew Changes | Files |
|------------|------------------|-------|
| **traitor** | `_locate_weakpoint.dm` - Generates scan objectives from ship areas instead of station areas. Gets areas from `SSshuttle.get_containing_shuttle()` and ship's `shuttle_areas` | `voidcrew/edits/antagonist/_locate_weakpoint.dm` |
| **blob** | Wasteland faction variants for blob mobs (spore, blobbernaut) with different stats | `voidcrew/modules/antagonist/blob/blob_mobs.dm` |
| **cult** | Custom Cult Bastard Sword with soul-stealing, spin attack, and special interactions with heretics | `voidcrew/modules/antagonist/cult/cult_bastard_sword.dm` |

---

#### FULLY AVAILABLE (No changes needed - work as-is from TG):

| Antagonist | Description | Ship Compatibility |
|------------|-------------|-------------------|
| **brainwashing** | Mind control through directives | COMPATIBLE - Works on any mob |
| **brother** | Blood brother team with conversion flash | COMPATIBLE - Social antag |
| **changeling** | Shapeshifting DNA-absorbing creature | COMPATIBLE - Works anywhere |
| **ert** | Emergency Response Team (not a true antag) | COMPATIBLE - Can respond to ships |
| **evil_clone** | Clone that must kill all copies of themselves | COMPATIBLE - Identity-based |
| **greentext** | Meta-antag for completing all objectives | COMPATIBLE - Works anywhere |
| **heretic** | Occult power-seeker with ritual sacrifices | COMPATIBLE - Area-independent |
| **hypnotized** | Victim of hypnosis brain trauma | COMPATIBLE - Works on any carbon |
| **magic_servant** | Servant created by magic | COMPATIBLE - Simple master/servant |
| **morph** | Shape-shifting mimic creature | COMPATIBLE - Works anywhere |
| **nightmare** | Shadow creature that hates light | COMPATIBLE - Works in darkness |
| **obsessed** | Stalker with obsessive objectives | COMPATIBLE - Target-based |
| **paradox_clone** | Time-displaced duplicate | COMPATIBLE - Identity-based |
| **pyro_slime** | Pyroclastic anomaly ghost role | COMPATIBLE - Fire-based |
| **revenant** | Ghost that drains life essence | COMPATIBLE - Works anywhere |
| **santa** | Christmas gift-giver (seasonal) | COMPATIBLE - Works anywhere |
| **sentient_creature** | Sentient animal with master | COMPATIBLE - Works anywhere |
| **shade** | Soul shard creature bound to master | COMPATIBLE - Works anywhere |
| **space_ninja** | Stealth saboteur with cyber suit | HIGH - Ship infiltration |
| **spiders** | Spider infestation with queen orders | COMPATIBLE - Works anywhere |
| **spy** | Bounty hunter collecting items | COMPATIBLE - Works with loot system |
| **survivalist** | Self-preservation focused antag | COMPATIBLE - Works anywhere |
| **syndicate_monkey** | Syndicate agent's monkey companion | COMPATIBLE - Works anywhere |
| **valentines** | Date protection (seasonal) | COMPATIBLE - Works anywhere |
| **venus_human_trap** | Plant infestation antagonist | COMPATIBLE - Works anywhere |
| **voidwalker** | Space entity that curses spacers | HIGH - Perfect for void setting |
| **wishgranter** | Corrupted wish-granter with powers | COMPATIBLE - Works anywhere |
| **xeno** | Xenomorph hive antagonist | COMPATIBLE - Works anywhere |

---

#### VOIDCREW-SPECIFIC ADDITIONS:

| Antagonist | Description | Files |
|------------|-------------|-------|
| **crewmember** | Ship faction team membership with HUD | `voidcrew/modules/antagonist/crewmember/crew.dm` |

The crewmember antag datum is used for ship team identification:
- Shows "FRND" on faction HUD
- Links to `datum/team/voidcrew` via `owner.ship_team`
- Silent (no greet message)
- Not shown in roundend or antag panel

---

#### IMPLEMENTATION NOTES FOR SHIP-BASED SETTING:

**High Priority Adaptations:**
1. **Pirate** - Already thematically perfect. Would need ship-based ransom demands and boarding mechanics.
2. **Battlecruiser** - Ideal for ship combat. Create hostile NPC ships or player-controlled warships.
3. **Space Ninja** - Infiltration of player ships. Already has stealth mechanics.
4. **Voidwalker** - Already space-themed. Could haunt ships passing through certain sectors.
5. **Space Dragon** - Could create rifts on ships, spawn carp as space encounters.

**Medium Priority:**
1. **Nukeops** - Could target specific player ships instead of station. Nuke a flagship.
2. **Abductors** - Mothership could be an overmap entity. Abduct from multiple ships.
3. **Fugitive/Hunters** - Cross-ship pursuit gameplay.
4. **Wizard** - Teleport between ships, raid for artifacts.

**Low Priority (Need Significant Rework):**
1. **Revolution** - Would need to rethink without station command hierarchy.
2. **Malf AI** - Ship AIs are different from station AI.
3. **Highlander** - Needs a contained arena, maybe a derelict station.
4. **Ashwalker** - Tied to Lavaland mining dimension.

**Key Considerations:**
- Most antags work because they're mob-based, not area-based
- Objectives may need adaptation (kill targets across ships, steal from specific ships)
- Team-based antags need spawn points on neutral ships/stations
- Some antags benefit from the "multiple ships" dynamic (fugitives, pirates, ninja)
- The traitor `_locate_weakpoint` edit shows the pattern: override objective generation to use ship areas

---

#### KEY FILES:
```
TG Antagonists Base: code/modules/antagonists/
  - _common/ (shared components, team datums)
  - traitor/datum_traitor.dm (main traitor antag)
  - changeling/changeling.dm (changeling antag)
  - heretic/heretic_antag.dm (heretic antag)
  - cult/datums/cultist.dm (blood cult antag)
  - nukeop/datums/operative.dm (nuclear operative)
  - wizard/wizard.dm (wizard antag)

Voidcrew Antagonist Modules: voidcrew/modules/antagonist/
  - blob/blob_mobs.dm (wasteland blob variants)
  - crewmember/crew.dm (ship team membership)
  - cult/cult_bastard_sword.dm (custom cult weapon)

Voidcrew Antagonist Edits: voidcrew/edits/antagonist/
  - _locate_weakpoint.dm (traitor objective adaptation)

Ship Teams: voidcrew/modules/teams/_team.dm
  - datum/team/voidcrew (ship faction system)
  - Integrates with crewmember antag datum
```

---



### SHUTTLE/DOCKING ANALYSIS
**Agent:** Shuttles
**Status:** Complete
**Date:** 2025-12-30

#### TG SHUTTLE SYSTEM OVERVIEW:
The TG shuttle system is built around **docking ports** - invisible objects that define shuttle boundaries and docking locations. There are two main types:

| Type | Purpose | Location |
|------|---------|----------|
| Mobile Docking Port | Defines a movable shuttle | `code/modules/shuttle/mobile_port/mobile_port.dm` |
| Stationary Docking Port | Defines a fixed docking location | `code/modules/shuttle/stationary_port/stationary_port.dm` |

#### CORE DOCKING PORT SYSTEM (`shuttle.dm`):
Base `/obj/docking_port` properties:
- `shuttle_id` - Unique identifier for the port/shuttle
- `port_destinations` - Compatible destination ports
- `width/height` - Size of covered area
- `dwidth/dheight` - Position offsets relative to covered area
- `dir` - Direction port faces (NORTH points into ship)
- `hidden` - Whether invisible to navigation computers
- `delete_after` - Auto-delete when shuttle leaves

Key procs:
- `return_coords()` - Returns bounding box coordinates
- `return_turfs()` - Returns turfs within shuttle boundaries
- `return_ordered_turfs()` - Returns turfs in consistent order for movement
- `get_docked()` - Returns currently docked mobile/stationary port
- `is_in_shuttle_bounds()` - Checks if atom is within shuttle

#### MOBILE DOCKING PORTS (`mobile_port.dm`):
Mobile ports define shuttles that can move between locations.

Key Variables:
- `shuttle_areas` - Areas belonging to this shuttle
- `engine_list` - Engines propelling the shuttle
- `engine_coeff` - Speed multiplier from engines
- `current_engine_power` - Current thrust capacity
- `mode` - Current state (SHUTTLE_IDLE, SHUTTLE_CALL, etc.)
- `callTime` - Transit time (deciseconds)
- `ignitionTime` - Engine startup time (55ds default)
- `rechargeTime` - Post-arrival cooldown
- `prearrivalTime` - Pre-arrival delay
- `preferred_direction` - Travel animation direction
- `port_direction` - Port position relative to shuttle front
- `destination` - Target stationary port
- `previous` - Last docked location
- `assigned_transit` - Transit z-level port
- `launch_status` - Endgame launch state
- `movement_force` - Force applied on launch

Shuttle Modes:
- SHUTTLE_IDLE - Stationary, not moving
- SHUTTLE_IGNITING - Engines warming up
- SHUTTLE_CALL - In transit to destination
- SHUTTLE_RECALL - Returning to origin
- SHUTTLE_DOCKED - At destination, waiting
- SHUTTLE_ESCAPE - Emergency escape flight
- SHUTTLE_RECHARGING - Post-arrival recharge
- SHUTTLE_PREARRIVAL - Landing sequence
- SHUTTLE_STRANDED - Unable to move
- SHUTTLE_DISABLED - Damaged/offline

Key Procs:
- `request()` - Call shuttle to a destination
- `cancel()` - Abort and return
- `initiate_docking()` - Execute shuttle move
- `enterTransit()` - Move to transit z-level
- `canMove()` - Check if shuttle can move
- `canDock()` - Check if destination is valid
- `check()` - Timer/mode processing
- `linkup()` - Connect machinery to shuttle

#### SHUTTLE MOVEMENT SYSTEM (`shuttle_move.dm`):
Movement Process:
1. `preflight_check()` - Validate source and destination turfs
2. `takeoff()` - Move atoms and turfs
3. `cleanup_runway()` - Handle areas and post-move callbacks

Movement Phases per Turf:
- `beforeShuttleMove()` - Pre-move callbacks
- `fromShuttleMove()` - Source turf departure logic
- `toShuttleMove()` - Destination turf arrival logic
- `onShuttleMove()` - During-move processing
- `afterShuttleMove()` - Post-move cleanup
- `lateShuttleMove()` - Final callbacks

Move Modes (bitflags):
- MOVE_AREA - Move the area to new turf
- MOVE_TURF - Move the turf type
- MOVE_CONTENTS - Move atoms on the turf

#### SHUTTLE VARIANTS:

**Emergency Shuttle** (`emergency.dm`):
- Endgame shuttle for crew evacuation
- Hijack detection system
- Shuttle events during transit
- Priority announcements
- Override docking checks (always lands)

**Supply Shuttle** (`supply.dm`):
- Cargo purchase/sell system
- Blacklist for dangerous items
- Mail generation system
- Centcom trade integration

**Navigation Computer** (`navigation_computer.dm`):
- Camera-like view for selecting landing spots
- Visual placement preview (red/green overlays)
- Rotation of landing orientation
- Custom docking port creation
- Whitelist turf validation

---

#### VOIDCREW SHUTTLE MODIFICATIONS:

##### Voidcrew Docking Port (`voidcrew/mapping/docking_port/_docking_port.dm`):
Custom mobile port for ship-based gameplay.

Key Variables:
- `z_levels_above/below` - Multi-z ship support
- `old_z_level` - Cached previous z-level
- `current_ship` - Linked overmap ship object
- `spawn_points` - Cryopod spawn locations
- `cryo_console` - Linked cryopod console

Key Features:
- **Z-Level Linking**: Manages ZTRAIT_STATION for ship z-levels
- **Multi-Ship Z-Level Probing**: Uses signals to prevent removing station traits when other ships present
- **Overmap Integration**: Links shuttle to overmap ship object
- **Spawn Point Management**: Tracks cryopods for respawning
- **Mothball System**: Cleanup for abandoned ships

Key Procs:
- `link_to_z_level()` - Add ship z-level to station levels
- `unlink_from_z_level()` - Remove z-level from station (with ship probe)
- `respond_to_z_port_probe()` - Signal handler for z-level checks
- `get_all_humans()` - List living crew members
- `mothball()` - Convert ship to ruin
- `recalculate_shuttle_areas()` - Refresh area flags

##### Emergency Shuttle Disabled (`voidcrew/modules/shuttle/emergency.dm`):
- `request()` proc is empty/disabled
- `requestEvac()` shows "currently impossible" message
- Ships ARE the escape in Voidcrew

##### Helm Console (`voidcrew/modules/shuttle/helm/_helm.dm`):
Ship control interface features:
- Overmap ship connection
- Engine management display
- Thrust/heading control
- Ship integrity monitoring (55% alert threshold)
- Bluespace jump calibration (3 minute sequence)
- Dock/undock controls
- Ship renaming
- Empty space docking

Jump Sequence States:
1. JUMP_STATE_OFF - Idle
2. JUMP_STATE_CHARGING - 3 minute charge
3. JUMP_STATE_IONIZING - Pylon ionization
4. JUMP_STATE_FIRING - Pylon launch
5. JUMP_STATE_FINALIZED - Jump execution (ship removal)

##### Survey Console (`voidcrew/modules/shuttle/survey/survey_computer.dm`):
Orbital survey and precision docking system:
- Celestial object surveying for research points/credits
- Custom docking location selection
- Research tier upgrades (view range, mob/obj sight)
- Survey data disk storage
- Planet loading integration
- Lighting setup for docked ships
- Area-based landing restrictions

Survey Values:
| Object Type | Points | Cash |
|-------------|--------|------|
| Nebula | 50 | 50 |
| Meteor | 100 | 100 |
| Electric Storm | 250 | 250 |
| EMP Storm | 400 | 400 |
| Planet | 500 | 500 |
| Star | 1000 | 1000 |
| Space Ruin | 300 | 300 |

Research Tier Bonuses:
- Advanced: 1.2x, mapping enabled
- Superior: 1.5x, object sight
- Elite: 2x, mob sight, 20 view range

##### Engine System (`voidcrew/modules/shuttle/engine/`):
Custom ship propulsion system.

Engine Types:
| Type | Fuel | Thrust | Notes |
|------|------|--------|-------|
| Ion Thruster | Electric | N/A | Power-based |
| Plasma Thruster | Plasma gas | 25 | Requires heater |
| Expulsion Thruster | Any gas | 15 | Inefficient, versatile |
| Void Thruster | None | N/A | End-game, no fuel |
| Oil Thruster | Oil liquid | N/A | Liquid-based |

Fuel Consumption:
- Scales with ship mass (`get_mass_fuel_multiplier()`)
- Reference mass: REFERENCE_SHIP_MASS
- Minimum 0.5x multiplier for small ships

##### Ship Parts System (`voidcrew/modules/shuttle/ship_parts/`):
Rarity-based ship parts for purchasing ships:
- Common (gray) - Basic components
- Uncommon (green) - Mid-tier ships
- Rare (blue) - Advanced vessels
- Epic (purple) - Elite vessels
- Legendary (orange) - Most powerful ships

---

#### IMPLEMENTATION STATUS:

| Feature | TG Status | Voidcrew Status | Notes |
|---------|-----------|-----------------|-------|
| Basic Shuttle Movement | WORKING | INHERITED | Full system |
| Docking Ports | WORKING | EXTENDED | Added voidcrew subtype |
| Emergency Shuttle | WORKING | DISABLED | Ships ARE the escape |
| Supply Shuttle | WORKING | LIKELY UNUSED | No cargo dept |
| Navigation Computer | WORKING | EXTENDED | Survey console uses this |
| Transit System | WORKING | INHERITED | For ship movement |
| Shuttle Console | WORKING | REPLACED | Helm console instead |
| Engine System | BASIC | HEAVILY EXTENDED | Fuel types, thrust |
| Ship Construction | N/A | NEW | Full RCD-based system |
| Survey System | N/A | NEW | Research/docking |
| Ship Parts Economy | N/A | NEW | Rarity-based currency |
| Bluespace Jump | N/A | NEW | End-game ship removal |
| Z-Level Management | BASIC | HEAVILY EXTENDED | Multi-ship support |

---

#### KEY FILES:

TG Shuttle Core:
- code/modules/shuttle/shuttle.dm (base docking port)
- code/modules/shuttle/mobile_port/mobile_port.dm (movable shuttles)
- code/modules/shuttle/mobile_port/shuttle_move.dm (movement mechanics)
- code/modules/shuttle/stationary_port/stationary_port.dm (fixed docks)
- code/modules/shuttle/stationary_port/port_types.dm (transit, etc.)
- code/modules/shuttle/shuttle_consoles/shuttle_console.dm (basic control)
- code/modules/shuttle/shuttle_consoles/navigation_computer.dm (custom docking)

TG Shuttle Variants:
- code/modules/shuttle/mobile_port/variants/emergency/emergency.dm
- code/modules/shuttle/mobile_port/variants/supply.dm
- code/modules/shuttle/mobile_port/variants/pods.dm

Voidcrew Shuttles:
- voidcrew/mapping/docking_port/_docking_port.dm (voidcrew mobile port)
- voidcrew/modules/shuttle/emergency.dm (disabled evac)
- voidcrew/modules/shuttle/helm/_helm.dm (ship control)
- voidcrew/modules/shuttle/survey/survey_computer.dm (orbital survey)
- voidcrew/modules/shuttle/engine/shuttle_engine.dm (base engine)
- voidcrew/modules/shuttle/engine/fuel.dm (fueled engines)
- voidcrew/modules/shuttle/engine/electric.dm (ion thruster)
- voidcrew/modules/shuttle/engine/void.dm (void thruster)
- voidcrew/modules/shuttle/engine/liquid.dm (oil thruster)
- voidcrew/modules/shuttle/engine/shuttle_heater.dm (fuel heater)
- voidcrew/modules/shuttle/construction/construction_console.dm
- voidcrew/modules/shuttle/boards.dm (circuit boards)
- voidcrew/modules/shuttle/design.dm (techwebs)
- voidcrew/modules/shuttle/ship_parts/ship_item.dm (parts currency)

---

#### CRITICAL INTEGRATION POINTS:

1. **SSshuttle Subsystem**: Central controller for all shuttle operations
2. **SSmapping**: Z-level traits, transit reservations
3. **Overmap System**: Ship objects link to docking ports
4. **Power System**: Engines connect via `connect_to_shuttle()`
5. **Atmospherics**: Fuel heaters use atmos components
6. **Techweb**: Research unlocks survey tiers, engine designs
7. **Ship Economy**: Parts database for ship purchasing

---

#### SIGNALS USED:
- COMSIG_GLOB_Z_SHIP_PROBE - Multi-ship z-level coordination
- COMSIG_SHUTTLE_SHOULD_MOVE - Block shuttle movement
- COMSIG_SHIP_INTEGRITY_CHANGED - UI updates
- COMSIG_VOIDCREW_SHIP_MOVED - Cancel survey on movement
- COMSIG_VOIDCREW_SHIP_DOCKED - Survey lighting setup
- COMSIG_VOIDCREW_SHIP_UNDOCKED - Survey cleanup
- COMSIG_VOIDCREW_PLANET_LOADED - Survey completion trigger
- COMSIG_SUPPLY_SHUTTLE_BUY - Cargo purchase hook

---
### MODULES A-H ANALYSIS
**Agent:** Modules A-H
**Status:** Complete
**Date:** 2025-12-30

#### MODULE STATUS:
| Module | Purpose | Voidcrew Status | Ship Relevance |
|--------|---------|-----------------|----------------|
| actionspeed | Movement speed modifiers for mobs - handles buffs/debuffs to walking/running speed | None | Medium - Affects all player movement |
| admin | Admin tools - verbs, panels, bans, player management, outfit editor, smites | None | Low - Standard admin infrastructure |
| art | Paintings and statues - decorative art objects | None | Low - Decorative only |
| assembly | Circuit assemblies - timers, signalers, proximity sensors, igniters, mousetraps | None | Medium - Used in bombs/traps |
| asset_cache | Client asset caching system - sprite sheets, icon loading | None | Low - Core infrastructure |
| atmospherics | CRITICAL: Gas simulation, pipenets, vents, scrubbers, reactions, fires | None | HIGH - Ship life support |
| autowiki | Automated wiki generation from game data | None | NA - Development tool only |
| awaymissions | Away missions - z-level exploration areas, gateways | None | HIGH - Could be overmap destinations |
| balloon_alert | Floating text alerts above heads | None | Low - UI element |
| basketball | Basketball minigame with hoops, teams, referee | None | Low - Recreation activity |
| bitrunning | Virtual domain exploration job - netpod minigame for loot | None | Medium - Cargo dept job |
| buildmode | Admin build mode for quick construction | None | Low - Admin tool |
| capture_the_flag | CTF minigame with teams, flags, classes | None | Low - Minigame |
| cards | Playing cards, card hands, deck manipulation | None | Low - Recreation item |
| cargo | Supply ordering, bounties, exports, shipping, markets | **EDITED** | HIGH - Ship economy core |
| chatter | Speech sound effects - phoneme-based talking sounds | None | Low - Audio enhancement |
| client | Client connection handling, preferences, verbs | None | Low - Core infrastructure |
| clothing | All wearable items - suits, helmets, belts, etc. | **EDITED** | Medium - Player equipment |
| deathmatch | Deathmatch minigame with loadouts and maps | None | Low - Minigame |
| debugging | Debug tools - Tracy profiler, debugger | None | NA - Development only |
| detectivework | Evidence and forensic scanners | None | Low - Detective gameplay |
| discord | Discord integration - account linking, embeds, TGS commands | None | Low - External integration |
| economy | Bank accounts, paychecks, holopay terminals | **EDITED** | HIGH - Ship economy |
| emoji | Emoji parsing for chat messages | None | Low - Chat enhancement |
| emote_panel | Emote selection UI panel | None | Low - UI element |
| engineering | Engineering tools (multitool arrow overlay) | None | Medium - Engineering gameplay |
| error_handler | Runtime error handling and viewer | None | NA - Debug infrastructure |
| escape_menu | ESC menu UI - leave body, disconnect options | None | Low - UI element |
| events | Random events - meteor showers, ion storms, disease outbreaks, etc. | None | HIGH - Need ship variants |
| experisci | Experimental science - destructive scanners, experiments | None | Medium - Science gameplay |
| explorer_drone | Exploration drones for remote site scanning | None | HIGH - Overmap exploration |
| fishing | Fishing minigame - rods, bait, fish catalog, aquariums | None | Medium - Recreation/Food |
| flufftext | Dreaming system for sleeping players | None | Low - Flavor text |
| food_and_drinks | Food items, cooking, restaurants, pizza boxes | **EDITED** | Medium - Crew sustenance |
| forensics | Forensic evidence helpers | None | Low - Detective gameplay |
| hallucination | Hallucination effects - fake alerts, sounds, visuals | None | Low - Status effect |
| holiday | Holiday detection and special events | None | Low - Seasonal content |
| holodeck | Holodeck recreation room simulation | None | Low - Recreation |
| hydroponics | Plant growing, seeds, bee keeping, biogenerator | None | Medium - Food production |

#### VOIDCREW EDITS DETAIL:

**Cargo (`voidcrew/modules/cargo/`):**
- `bank_account.dm` - Ship-based bank accounts with shipping container tracking
- `bank_machine.dm` - Modified for ship economy
- `ntpay.dm` - Payment system modifications
- `shipping/` - Complete shipping system:
  - `beacon.dm` - Shipping beacons for delivery
  - `cargo_console.dm` - Modified cargo ordering console
  - `purchasing.dm` - Ship purchase system
  - `shipping_container.dm` - Container management

**Clothing (`voidcrew/modules/clothing/`):**
- `gloves/insulated.dm` - Insulated glove modifications
- `head/helmet.dm` - Helmet additions
- `suits/armor.dm` - Armor variants
- `under/accessories.dm` - Uniform accessories
- `under/solgov.dm` - SolGov faction uniforms

**Economy (`voidcrew/edits/subsystem/economy.dm`):**
- Removed roundstart paychecks
- Removed budget pool (no free money)
- Added export_total and import_total tracking

**Food and Drinks (`voidcrew/modules/food_and_drinks/drinks/`):**
- `bottles.dm` - Custom drink bottles

#### NOT IMPLEMENTED/NEEDS WORK:

| Module | Issue | Priority |
|--------|-------|----------|
| atmospherics | No ship-specific atmos systems, uses station assumptions | HIGH |
| awaymissions | Gateway system station-focused, not overmap integrated | HIGH |
| events | Most events assume station context (shuttle_loan, grid_check, tram_malfunction) | HIGH |
| explorer_drone | Uses abstract "exploration sites", not overmap locations | MEDIUM |
| bitrunning | Station-focused job spawning | LOW |
| holodeck | Station recreation area only | LOW |
| hydroponics | Works but not optimized for ship space | LOW |

#### IMPLEMENTATION IDEAS:

**Atmospherics for Ships:**
- Ship breach events with hull repair mechanics
- Portable/compact life support systems
- Emergency atmos reservoirs for small ships
- Fuel tank integration for plasma/gas storage

**Away Missions to Overmap:**
- Replace gateway with shuttle travel to overmap destinations
- Convert away mission z-levels to procedural planet zones
- Link exile pamphlet to specific planet locations

**Events for Ships:**
- Replace station events with ship equivalents:
  - `shuttle_catastrophe` -> Ship system failures
  - `grid_check` -> Engine power fluctuations
  - `meteor` events already work
  - `communications_blackout` -> Sensor interference
  - `ion_storm` -> Already applicable
- Add ship-specific events:
  - Hull breach (atmospherics)
  - Pirate encounter (combat)
  - Distress signal (rescue mission)
  - Fuel shortage (resource management)

**Explorer Drones to Overmap:**
- Link drone exploration sites to overmap sectors
- Use scanner array to discover new overmap locations
- Drone loot tables based on sector type

**Economy Improvements:**
- Per-ship budget tracking (already started)
- Inter-ship trade mechanics
- Fuel cost calculations
- Repair cost integration

#### KEY FILES REFERENCE:
```
TG Modules (code/modules/):
atmospherics/         - Gas simulation, CRITICAL for ships
cargo/               - Supply ordering, has Voidcrew edits
events/              - Random events, need ship variants
explorer_drone/      - Remote exploration, overmap potential
economy/             - Bank accounts, modified by Voidcrew

Voidcrew Edits:
voidcrew/modules/cargo/           - Ship economy
voidcrew/modules/clothing/        - Faction clothing
voidcrew/modules/food_and_drinks/ - Custom drinks
voidcrew/edits/subsystem/economy.dm - Economy changes
```

### JOBS/ROLES ANALYSIS
**Agent:** Jobs (a03223e)
**Status:** Complete
**Date:** 2025-12-30

#### TG JOB SYSTEM OVERVIEW:

The TG job system is built around the `/datum/job` datum which defines all properties for crew positions. Jobs are organized into departments, have associated outfits, access levels via ID trims, and are managed by the SSjob subsystem.

#### TG JOBS BY DEPARTMENT:

| Department | Jobs | Head of Staff | Voidcrew Status |
|------------|------|---------------|-----------------|
| **Command** | Captain, HoP, HoS, CE, CMO, RD, QM | Captain | MODIFIED - Ship-based |
| **Security** | HoS, Warden, Detective, Security Officer | HoS | INHERITED |
| **Engineering** | CE, Station Engineer, Atmospheric Technician | CE | INHERITED |
| **Medical** | CMO, Medical Doctor, Chemist, Geneticist, Coroner, Paramedic, Psychologist | CMO | INHERITED |
| **Science** | RD, Scientist, Roboticist | RD | INHERITED |
| **Cargo** | QM, Cargo Technician, Shaft Miner | QM | INHERITED |
| **Service** | HoP, Bartender, Cook, Botanist, Janitor, Curator, Chaplain, Lawyer, Clown, Mime | HoP | INHERITED |
| **Silicon** | AI, Cyborg | AI | INHERITED |
| **Assistant** | Assistant | None | INHERITED |

#### TG JOB DATUM KEY VARIABLES:

| Variable | Purpose | Example |
|----------|---------|---------|
| `title` | Job name used for prefs/bans | `JOB_CAPTAIN` |
| `department_head` | Who supervises this job | `list(JOB_CAPTAIN)` |
| `total_positions` | Max players with this job | 1 |
| `spawn_positions` | Roundstart slots | 1 |
| `outfit` | Outfit datum for equipment | `/datum/outfit/job/captain` |
| `exp_requirements` | Minutes of play required | 180 |
| `paycheck` | Credits per paycheck | `PAYCHECK_COMMAND` |
| `job_flags` | Bitflags for job properties | `STATION_JOB_FLAGS` |

#### TG JOB SUBSYSTEM (SSjob):

Location: `code/controllers/subsystem/job.dm`

**Chain of Command:**
1. Captain
2. Head of Personnel
3. Research Director
4. Chief Engineer
5. Chief Medical Officer
6. Head of Security
7. Quartermaster

**Priority Levels:** JP_HIGH, JP_MEDIUM, JP_LOW

**Overflow Role:** Assistant (configurable)

#### VOIDCREW JOB MODIFICATIONS:

**1. New Job Variables** (`voidcrew/edits/jobs.dm`):
- `officer` (boolean) - Is ship leader?
- `job_category` - For category-based prefs (JOB_CAT_*)

**2. Job Categories** (`voidcrew/_DEFINES/job_categories.dm`):
- JOB_CAT_COMMAND, JOB_CAT_SECURITY, JOB_CAT_ENGINEERING
- JOB_CAT_MEDICAL, JOB_CAT_SCIENCE, JOB_CAT_CARGO
- JOB_CAT_SERVICE, JOB_CAT_ASSISTANT

**3. SSjob Overrides** (`voidcrew/edits/subsystem/job.dm`):
- `set_overflow_role()` - Disabled (ships handle their own)
- `divide_occupations()` - Completely replaced, defers to ticker

**4. Character Creation Override** (`voidcrew/edits/subsystem/ticker.dm`):
- Gets roundstart ship from SSovermap
- Matches category prefs to available jobs
- Assigns by priority level (HIGH -> MEDIUM -> LOW)
- Fallback to random available job

**5. Ship Job Slots** (`voidcrew/mapping/shuttles/_shuttle.dm`):
Each ship template defines its own job_slots list with:
- name: Custom job title
- officer: Is this the ship leader?
- outfit: Equipment outfit
- category: Job category for matching
- slots: Number of positions

#### SHIP-SPECIFIC JOB EXAMPLES:

**Box-class Hospital Ship:**
- Chief Medical Officer (Command, 1, Officer)
- Medical Doctor (Medical, 3)
- Paramedic (Medical, 2)
- Assistant (Assistant, 3)

**Kilo-class Mining Ship:**
- Captain (Command, 1, Officer)
- Foreman (Cargo, 1) - custom title for QM
- Ship's Doctor (Medical, 2)
- Ship's Engineer (Engineering, 1)
- Asteroid Miner (Cargo, 2)
- Deckhand (Assistant, 2)

#### LATEJOIN PROCESS (Voidcrew):

1. `select_ship()` - Menu to pick active ship or purchase new
2. `AttemptSpawnOnShip(job, ship)`:
   - Decrements ship's job slots
   - Assigns role via SSjob
   - Creates character at ship spawn point
   - Equips outfit
   - Injects into ship manifest
   - Registers with ship team

#### KEY DIFFERENCES: TG vs VOIDCREW:

| Aspect | TG Station | Voidcrew Ships |
|--------|------------|----------------|
| Job Source | Global job list | Per-ship job_slots |
| Assignment | divide_occupations | create_characters |
| Preferences | Specific jobs | Categories |
| Overflow | Assistant | Ship's officer |
| Spawn Points | Station landmarks | Ship spawn_points |
| Latejoin | Single station | Select from ships |

#### KEY FILES:

TG Job System:
- code/controllers/subsystem/job.dm
- code/modules/jobs/job_types/_job.dm
- code/modules/jobs/departments/departments.dm
- code/datums/id_trim/jobs.dm

Voidcrew Overrides:
- voidcrew/edits/jobs.dm
- voidcrew/edits/subsystem/job.dm
- voidcrew/edits/subsystem/ticker.dm
- voidcrew/edits/mobs/new_player.dm
- voidcrew/edits/preferences.dm
- voidcrew/_DEFINES/job_categories.dm
- voidcrew/mapping/shuttles/_shuttle.dm

#### NOT IMPLEMENTED:

| Feature | Notes |
|---------|-------|
| Dynamic job creation | Jobs static per template |
| Job requirements per ship | No exp/age checks |
| Cross-ship job transfer | Must cryo and rejoin |
| Ship-specific ID trims | Uses TG trims |
| Captain succession | No automatic system |
| Job objectives | No ship-specific objectives |

---

### OVERMAP ANALYSIS
**Agent:** Overmap
**Status:** Complete
**Date:** 2025-12-30

#### TG OVERMAP:
TG Station does **NOT** have an overmap system. The directory `code/modules/overmap/` exists but is **empty**. TG uses a single-station paradigm where the station is stationary and all gameplay happens in a fixed location.

#### VOIDCREW OVERMAP:
Voidcrew implements a complete custom overmap system from scratch. This is the **core differentiating feature** of Voidcrew - it converts SS13 from a stationary station game into a ship-based exploration game.

**Location:** `voidcrew/modules/overmap/`

#### SUBSYSTEM (SSovermap):
Location: `voidcrew/modules/overmap/code/controllers/subsystem/overmap.dm`

| Feature | Description |
|---------|-------------|
| Map Size | OVERMAP_SIZE constant (configurable) |
| Sun Setup | Central star generation (single or binary) |
| Orbital System | Turfs organized by radius from center |
| Event Clusters | Up to 8 clusters, 70 max events |
| Planet Spawning | Dynamic planet placement in orbits |
| Space Ruins | 3-5 randomly spawned space ruins |
| Initial Ship | Spawns starter ship for players |
| Bluespace Jump | End-round escape mechanism |
| Map Zones | Tracks dynamically loaded z-levels |

#### OVERMAP OBJECTS:
**Base Class:** `/obj/structure/overmap`
Location: `voidcrew/modules/overmap/code/modules/overmap/_overmap.dm`

| Object Type | File | Description |
|-------------|------|-------------|
| Ship | `ship.dm` | Player-controlled vessels |
| Planet | `planet.dm` | Landable celestial bodies |
| Star | `stars.dm` | Central sun(s) |
| Event | `events.dm` | Hazards/obstacles |
| Space Ruin | `space_ruin.dm` | Derelict locations |
| Dynamic | `dynamic_object_defines.dm` | Dynamically spawned objects |

#### SHIP SYSTEM (`/obj/structure/overmap/ship`):
**File:** `voidcrew/modules/overmap/code/modules/overmap/ship.dm`

| Feature | Implementation |
|---------|----------------|
| **Movement** | Grid-based with speed/acceleration |
| **Speed System** | `speed[2]` array for X/Y velocity |
| **Thrust** | Engine-based acceleration |
| **Docking States** | FLYING, DOCKING, UNDOCKING, IDLE, ACTING |
| **Ship Teams** | Crew organization via `/datum/team/voidcrew` |
| **Bank Account** | Shared ship economy |
| **Manifest** | Crew roster tracking |
| **Job Slots** | Per-ship job availability |
| **Map Rendering** | Camera-based overmap view |
| **Mass Calculation** | Turf-based (intact turfs = mass) |
| **Pending Dock** | Ship-to-ship docking handshake |
| **Deletion Timer** | Auto-delete abandoned ships |

#### SHIP DAMAGE SYSTEM:
**File:** `voidcrew/modules/overmap/code/modules/overmap/ship_damage.dm`

| Mechanic | Description |
|----------|-------------|
| **Integrity** | Based on turf count vs original |
| **Max Integrity** | Set at ship creation (first mass calc) |
| **Overhealth** | Expansion beyond original size |
| **Crash Landing** | At 50% integrity - force docks |
| **Critical Alerts** | Below 60% - warning sounds |
| **Recovery** | At 65% after crash - systems online |
| **Hazard Damage** | Storms trigger on-ship effects |

**Hazard Effects:**
| Hazard | Effect |
|--------|--------|
| Ion Storm | EMP pulses on ship |
| Electrical Storm | Light overloads, lightning strikes |
| Meteor Storm | Actual meteors spawn and hit ship |
| Nebula | Plasma contamination |

#### PLANET TYPES:
**File:** `voidcrew/modules/overmap/code/modules/overmap/behaviour/planets.dm`

| Planet Type | Traits | Map Generator |
|-------------|--------|---------------|
| Lava | Ash storms, volcanic | `planet_generator/lava` |
| Ice | Snow storms, frozen | `planet_generator/snow` |
| Beach | Rain storms, oceanic | `planet_generator/beach` |
| Jungle | Rain storms, tropical | `planet_generator` |
| Wasteland | Sand storms, industrial | `planet_generator/lava` |
| Asteroid | Mining, no weather | `cave_generator/asteroid` |
| Space | Space ruins only | None |
| Empty | Ship docking space | None |
| Crashed Ship | Distress signal | None |

#### EVENTS/HAZARDS:
**File:** `voidcrew/modules/overmap/code/modules/overmap/events.dm`

| Event | Variants | Spread Chance |
|-------|----------|---------------|
| Meteor Storm | Minor, Moderate, Major | 50% |
| Ion Storm | Minor, Moderate, Major | 20% |
| Electrical Storm | Minor, Moderate, Major | 30% |
| Nebula | Single type | 75% |

#### HELM CONSOLE:
**File:** `voidcrew/modules/shuttle/helm/_helm.dm`

| Feature | Description |
|---------|-------------|
| **Overmap View** | Camera-based map rendering |
| **Ship Control** | Thrust, heading, stop |
| **Engine Toggle** | Enable/disable engines |
| **Docking** | Dock to planets, ruins, ships |
| **Undocking** | Leave docked location |
| **Rename Ship** | Change ship name (5 min cooldown) |
| **Bluespace Jump** | End-round escape (3 min charge) |
| **Dock in Empty Space** | Creates empty zone for repairs |
| **Ship-to-Ship Docking** | Request docking with another ship |
| **Crew Check** | Only crew can operate |
| **Viewer Mode** | View-only variant |

**UI Data Provided:**
- Thrust, integrity, overhealth percentage
- Ship disabled/crashed state
- Engine info (fuel, enabled)
- Nearby objects
- Current position, heading, speed, ETA
- Docking status

#### SURVEY SYSTEM:
**File:** `voidcrew/modules/shuttle/survey/survey_computer.dm`

| Feature | Description |
|---------|-------------|
| **Survey Console** | Scan celestial objects for data |
| **Research Points** | Earned from surveying |
| **Cash Rewards** | Monetary rewards for discoveries |
| **Survey Data** | Stored per-ship and on disks |
| **Camera Mode** | Remote viewing for landing spots |
| **Tier Upgrades** | Better range/features via research |
| **Mapping** | Planet surface mapping |
| **Mob/Obj Sight** | See entities through terrain |

**Survey Point Values:**
| Object | Base Points |
|--------|-------------|
| Nebula | 50 |
| Asteroid | 100 |
| Electrical Storm | 250 |
| EMP Storm | 400 |
| Planet | 500 |
| Star | 1000 |
| Space Ruin | 300 |

**Bonuses:** First surveyor gets 1.2x, research tiers add up to 2x.

#### DOCKING SYSTEM:

**Planet/Ruin Docking:**
1. Ship enters overmap tile with planet
2. Player initiates via helm console
3. Level dynamically loads if needed
4. Two docking ports available per location
5. Shuttle moves to stationary port
6. Ship state changes to IDLE

**Ship-to-Ship Docking:**
1. Ship A requests dock with Ship B
2. Ship B must also request within 30 seconds
3. Empty space zone created
4. Both ships dock exit-to-exit
5. Airlocks can connect

**Empty Space Docking:**
- Creates a shared z-level
- For ship repairs, construction
- Auto-cleanup when ships leave

#### SECTOR GENERATION:

**At Round Start:**
1. Create overmap area/turfs
2. Place central star
3. Build orbital ring system
4. Spawn event clusters (storms, nebulae)
5. Spawn planets from mapping config
6. Spawn space ruins (3-5 random)
7. Spawn initial ship for players

**Dynamic Loading:**
- Planets generate terrain on first visit
- Ruins load from templates
- Auto-cleanup when no players remain

#### FEATURES:
| Feature | Status | Notes |
|---------|--------|-------|
| Overmap Grid | WORKING | Full grid-based navigation |
| Ship Movement | WORKING | Physics-based thrust system |
| Planet Docking | WORKING | Dynamic encounter generation |
| Space Ruins | WORKING | Template-based ruins |
| Hazard Events | WORKING | Multiple storm types |
| Ship Damage | WORKING | Turf-based integrity |
| Crash Landing | WORKING | Emergency forced docking |
| Survey System | WORKING | Full research integration |
| Helm Console | WORKING | Complete UI and controls |
| Ship Teams | WORKING | Crew management |
| Bluespace Jump | WORKING | End-round mechanism |
| Ship-to-Ship Docking | WORKING | Mutual request system |
| Ship Manifest | WORKING | Crew roster |
| Ship Bank | WORKING | Shared economy |

#### NOT IMPLEMENTED:
| Feature | Notes |
|---------|-------|
| Wormholes | Commented as "TODO: reimplement wormholes" |
| Multi-Z Ships | TODOs for calculate_turf_above/below |
| Midgame Planet Spawning | Code exists but commented out |
| Autopilot | References exist but not implemented |
| Ship Combat | No weapons/shield system |
| Faction System | Toggle KOS/return exists but incomplete |
| Sensor Range | Referenced but not implemented |
| Ship Repair Timer | Commented out repair timer |
| NPC Ships | All ships are player-controlled |

#### KEY FILES:
```
Subsystem:
- voidcrew/modules/overmap/code/controllers/subsystem/overmap.dm
- voidcrew/modules/overmap/code/controllers/subsystem/shuttle.dm

Core Objects:
- voidcrew/modules/overmap/code/modules/overmap/_overmap.dm
- voidcrew/modules/overmap/code/modules/overmap/ship.dm
- voidcrew/modules/overmap/code/modules/overmap/ship_damage.dm
- voidcrew/modules/overmap/code/modules/overmap/planet.dm
- voidcrew/modules/overmap/code/modules/overmap/events.dm
- voidcrew/modules/overmap/code/modules/overmap/stars.dm
- voidcrew/modules/overmap/code/modules/overmap/space_ruin.dm
- voidcrew/modules/overmap/code/modules/overmap/dynamic_object_defines.dm

Behaviors:
- voidcrew/modules/overmap/code/modules/overmap/behaviour/planets.dm
- voidcrew/modules/overmap/code/modules/overmap/behaviour/stars.dm

Areas/Turfs:
- voidcrew/modules/overmap/code/game/area/areas/overmap.dm
- voidcrew/modules/overmap/code/game/turfs/open/overmap.dm
- voidcrew/modules/overmap/code/game/turfs/closed/overmap.dm

Helm & Survey:
- voidcrew/modules/shuttle/helm/_helm.dm
- voidcrew/modules/shuttle/survey/survey_computer.dm
- voidcrew/modules/shuttle/survey/_survey_datum.dm

Icons:
- voidcrew/modules/overmap/icons/
```

#### INTEGRATION POINTS:
| System | Integration |
|--------|-------------|
| SSshuttle | Extended with create_ship() |
| SSmapping | Planet z-levels, map zones |
| SSair | Paused during ship loading |
| Research | Survey points feed techweb |
| Economy | Ship bank accounts |
| Jobs | Per-ship job slots |
| Teams | Ship crew management |
---


### ATMOSPHERICS ANALYSIS
**Agent:** Atmospherics
**Status:** Complete
**Date:** 2025-12-30

#### TG ATMOS SYSTEMS:

##### Gas Types (20 Total):
| Gas | ID | Specific Heat | Dangerous | Properties |
|-----|-----|--------------|-----------|------------|
| Oxygen | o2 | 20 | No | Required for respiration, oxidizer |
| Nitrogen | n2 | 20 | No | Atmospheric padding, very common |
| Carbon Dioxide | co2 | 30 | Yes | Suffocation, byproduct of respiration |
| Plasma | plasma | 200 | Yes | Flammable, visible overlay, core to reactions |
| Water Vapor | water_vapor | 40 | No | Condensation, slipperiness, fusion power 8 |
| Hyper-Noblium | nob | 2000 | No | Reaction suppression, fusion power 10 |
| Nitrous Oxide | n2o | 40 | Yes | Drowsiness, euphoria, unconsciousness |
| Nitrium | nitrium | 10 | Yes | Performance enhancer, fusion power 7 |
| Tritium | tritium | 10 | Yes | Radioactive, flammable, fusion power 5 |
| BZ | bz | 20 | Yes | Hallucinogenic nerve agent, fusion catalyst |
| Pluoxium | pluoxium | 80 | No | Super-oxygenation, fusion power -10 |
| Miasma | miasma | 20 | Yes | Biological pollutant, visible at 60x normal |
| Freon | freon | 600 | Yes | Coolant, endothermic reactions, fusion -5 |
| Hydrogen | h2 | 15 | Yes | Flammable, fusion power 2 |
| Healium | healium | 10 | Yes | Regenerative sleep induction |
| Proto-Nitrate | proto_nitrate | 30 | Yes | Volatile, variable reactions |
| Zauker | zauker | 350 | Yes | Toxic, regulated production |
| Halon | halon | 175 | Yes | Fire suppressant, oxygen removal |
| Helium | helium | 15 | No | Inert, fusion byproduct, fusion power 7 |
| Antinoblium | antinoblium | 1 | Yes | Fusion power 20, rare exotic |

Location: `code/modules/atmospherics/gasmixtures/gas_types.dm`

##### Gas Mixture System (Listmos):
The core of TG atmos uses "Listmos" - a highly optimized list-based gas storage system.

Key Procs:
- `assert_gas(path)` - Ensure gas exists before access
- `garbage_collect()` - Remove gases with <= 0 moles
- `share(sharer, coeff)` - Core equalization between mixtures
- `react(holder)` - Trigger gas reactions
- `return_pressure()` - Calculate kPa
- `heat_capacity()` - Calculate thermal energy capacity

Location: `code/modules/atmospherics/gasmixtures/gas_mixture.dm`

##### SSair Subsystem Processing Order:
1. Adjacent Rebuild - Calculate turf adjacencies
2. Pipenet Rebuild - Build/rebuild pipe networks
3. Pipenets - Process all pipe networks
4. Atmos Machinery - Vents, scrubbers, pumps, etc.
5. Active Turfs - Gas flow between tiles
6. Hotspots - Fire processing
7. Excited Groups - Equalization groups
8. High Pressure Delta - Spacewind/pressure movement
9. Superconductivity - Heat through solids
10. Atoms - Exposure processing

Location: `code/controllers/subsystem/air.dm`

##### Pipe Network Components:
| Component | Type | Purpose |
|-----------|------|---------|
| Pipe | Simple | Gas transport |
| Manifold | Branching | 3-way connection |
| Vent Pump | Unary | Push/pull gas to/from environment |
| Vent Scrubber | Unary | Remove specific gases |
| Pump | Binary | Pressure-based transfer |
| Volume Pump | Binary | Volume-based transfer |
| Filter | Trinary | Separate specific gases |
| Mixer | Trinary | Combine gases at ratios |
| Canister | Portable | Large gas storage (2000L) |

Locations:
- `code/modules/atmospherics/machinery/pipes/`
- `code/modules/atmospherics/machinery/components/`
- `code/modules/atmospherics/machinery/portable/`

##### Fire System:
- Created by `hotspot_expose()` when fuel + oxidizer + heat present
- Three stages: light, medium, heavy (bypassing)
- Burns turfs, objects, mobs via `fire_act()`
- Cold fires from Freon combustion

Location: `code/modules/atmospherics/environmental/LINDA_fire.dm`

##### Environmental Flow (LINDA):
- Active turfs: Currently processing gas exchange
- Excited groups: Turfs sharing gas, breakdown for equalization
- Spacewind: High pressure differences push objects
- Heat transfer via `temperature_share()` and superconductivity

Location: `code/modules/atmospherics/environmental/LINDA_turf_tile.dm`

#### VOIDCREW STATUS:

##### Inherited Systems (Full TG):
| System | Status |
|--------|--------|
| All 20 Gas Types | INHERITED |
| Listmos Gas Mixtures | INHERITED |
| All Chemical Reactions | INHERITED |
| SSair Subsystem | INHERITED |
| Pipe Networks | INHERITED |
| Air Alarms | INHERITED |
| Portable Equipment | INHERITED |
| Fire System | INHERITED |
| Environmental Flow | INHERITED |

##### Voidcrew-Specific Atmos:
| Feature | Location | Purpose |
|---------|----------|---------|
| Ship Fuel Systems | `voidcrew/modules/shuttle/engine/fuel.dm` | Plasma/gas-based ship propulsion |
| Engine Heater | `voidcrew/modules/shuttle/engine/shuttle_heater.dm` | Fuel gas source |
| Nebula Contamination | `voidcrew/modules/overmap/code/modules/overmap/ship_damage.dm` | Adds plasma to ship |

**Ship Engine Types:**
- Plasma Thruster: 20 mol fuel_use, 25 thrust
- Expulsion Thruster: 80 mol fuel_use, 15 thrust (any gas)

**Nebula Effect:** 30% chance to add 0.5 mol plasma to random ship turf.

#### NOT IMPLEMENTED:
| Feature | Description |
|---------|-------------|
| Ship-Wide Atmos Display | No unified atmospheric overview |
| Emergency Atmos Protocols | No ship-wide emergency venting |
| Fuel Efficiency Display | No UI for consumption rate |
| Atmos Hazard Alerts | No overmap-triggered alerts |
| External Tank Refueling | No docking-based fuel transfer |

#### KEY FILES:
```
TG Core:
- code/controllers/subsystem/air.dm
- code/modules/atmospherics/gasmixtures/gas_types.dm
- code/modules/atmospherics/gasmixtures/gas_mixture.dm
- code/modules/atmospherics/gasmixtures/reactions.dm
- code/modules/atmospherics/environmental/LINDA_*.dm
- code/modules/atmospherics/machinery/

Voidcrew:
- voidcrew/modules/shuttle/engine/fuel.dm
- voidcrew/modules/shuttle/engine/shuttle_heater.dm
- voidcrew/modules/overmap/code/modules/overmap/ship_damage.dm
```

---

### GAMEMODES/DYNAMIC ANALYSIS
**Agent:** Gamemodes
**Status:** Complete
**Date:** 2025-12-30

#### TG GAMEMODE SYSTEM:

**1. Dynamic Subsystem (SSdynamic)**

TG's "dynamic" gamemode is the modern replacement for classic gamemodes (traitor, nuke ops, etc.). It creates a varied, unpredictable game experience by:

- **Tier System**: At round start, a "tier" is selected (Greenshift, Low Chaos, Low-Medium Chaos, Medium-High Chaos, High Chaos) based on weighted probability
- **Rulesets**: Instead of fixed gamemodes, dynamic uses modular "rulesets" that spawn antagonists
- **Three Ruleset Categories**:
  - **Roundstart**: Selected before the round begins (traitor, changeling, nukeops, etc.)
  - **Midround**: Spawned during the round based on timers and conditions (light vs heavy midrounds)
  - **Latejoin**: Assigned to players who join after round start

**2. Tier Configuration**

Each tier defines:
- `weight`: Probability of being selected (weights sum to ~100)
- `min_pop`: Minimum population required
- `ruleset_type_settings`: Controls how many rulesets spawn per category

Tier settings per category include:
- `LOW_END` / `HIGH_END`: Range of how many rulesets to spawn
- `HALF_RANGE_POP_THRESHOLD` / `FULL_RANGE_POP_THRESHOLD`: Reduces max based on pop
- `TIME_THRESHOLD`: When midrounds/latejoins can start
- `EXECUTION_COOLDOWN_LOW/HIGH`: Time between midround spawns

**Example Tiers**:
| Tier | Roundstart Rulesets | Light Midround | Heavy Midround | Latejoin |
|------|---------------------|----------------|----------------|----------|
| Greenshift | 0 | 0 | 0 | 0 |
| Low | 1 | 0-2 | 0-1 | 0-1 |
| Low-Medium | 1-2 | 0-2 | 0-1 | 1-2 |
| Medium-High | 2-3 | 1-2 | 1-2 | 1-3 |
| High | 3-4 | 1-2 | 2-4 | 2-3 |

**3. Ruleset Properties**

Each ruleset has:
- `weight`: Selection probability (can vary by tier)
- `min_pop`: Minimum players needed
- `min_antag_cap` / `max_antag_cap`: How many antags to spawn
- `repeatable`: If it can be selected multiple times
- `ruleset_flags`: Special properties (RULESET_HIGH_IMPACT, RULESET_INVADER)
- `blacklisted_roles`: Jobs that can't be this antag
- `pref_flag`: Player preference that must be enabled

**4. Roundstart Rulesets (in `dynamic_ruleset_roundstart.dm`)**

| Ruleset | Weight | Min Pop | Notes |
|---------|--------|---------|-------|
| Traitor | 10 | 3 | Standard lone antag |
| Blood Brothers | 5 | 10 | Team antag |
| Changeling | 3 | 15 | Shapeshifter |
| Heretic | 3 | 30 | Sacrifice objectives |
| Malf AI | 0-3 (by tier) | 30 | HIGH_IMPACT |
| Wizard | 0-2 (by tier) | 30 | HIGH_IMPACT, INVADER |
| Blood Cult | 0-3 (by tier) | 30 | HIGH_IMPACT, team |
| Nuclear Operatives | 0-3 (by tier) | 30 | HIGH_IMPACT, INVADER |
| Revolution | 0-3 (by tier) | 30 | HIGH_IMPACT |
| Spies | 0-3 (by tier) | 10 | Spy vs spy |

**5. Midround Rulesets (in `dynamic_ruleset_midround.dm`)**

**Light Midrounds** (less impactful, spawn earlier):
- Pirates, Nightmare, Abductors, Revenant, Space Changeling, Paradox Clone, Voidwalker, Fugitives, Midround Traitor (from living)

**Heavy Midrounds** (more impactful, spawn later):
- Spiders, Heavy Pirates, Wizard, Nuclear Operatives, Blob, Xenomorph, Space Dragon, Space Ninja, Slaughter Demon, Malf AI (from living), Blob Infection

**6. Latejoin Rulesets (in `dynamic_ruleset_latejoin.dm`)**

- Latejoin Traitor (weight 10)
- Latejoin Heretic (weight 3, min_pop 30)
- Latejoin Changeling (weight 3, min_pop 15)
- Latejoin Revolution (weight 1, min_pop 30, requires 3 heads)

**7. Objectives System (in `objective.dm`)**

TG has extensive objective types:
- **Target-based**: Assassinate, Maroon, Debrain, Protect, Jailbreak
- **Escape-based**: Escape, Hijack, Survive, Martyr, Exile
- **Collection-based**: Steal, Absorb, Capture
- **Special**: Nuclear, Robot Army, Custom

`considered_escaped()` function checks:
- Is the player alive?
- Are they on CentCom/Syndie base?
- Not in shuttle brig (custody)
- Force_escaped flag (admin override)

**8. Round End Conditions**

The round ends when:
- Emergency shuttle reaches CentCom (`SHUTTLE_ENDGAME`)
- Station is nuked (`GLOB.station_was_nuked`)
- Supermatter cascade (`SSsupermatter_cascade.cascade_initiated`)
- Cult summons Nar'sie
- Admin force end

`set_round_result()` iterates through executed rulesets to determine the mode_result and news_report.

**9. Event System**

Dynamic can enable/disable antag events via `antag_events_enabled`. Events can:
- Trigger false alarms (announce threats that don't exist)
- Add rulesets to the queue
- Modify threat calculations

#### VOIDCREW IMPLEMENTATION:

**1. Round End Override** (in `voidcrew/gamemodes/game_mode.dm`):

```dm
/datum/controller/subsystem/ticker/check_finished()
    if(SSovermap.jump_mode == BS_JUMP_COMPLETED)
        return TRUE
    ..()
```

Voidcrew uses **Bluespace Jump** as the round end mechanism instead of the emergency shuttle:
- `BS_JUMP_IDLE`: Normal gameplay
- `BS_JUMP_CALLED`: Jump requested, countdown starts
- `BS_JUMP_INITIATED`: Jump in progress, can't be stopped
- `BS_JUMP_COMPLETED`: Round ends

**2. Ship Teams** (in `voidcrew/modules/teams/_team.dm`):

```dm
/datum/team/voidcrew
    show_roundend_report = TRUE
    var/obj/structure/overmap/ship/ship
```

Every player is assigned to a `/datum/team/voidcrew` based on their ship. This creates:
- Per-ship crew tracking
- Team-based roundend reporting
- Ship-specific objectives (potential)

**3. Crew Antagonist Datum** (in `voidcrew/modules/antagonist/crewmember/crew.dm`):

A pseudo-antag datum that marks players as crew members of a specific ship:
- Shows team HUD icons
- Links to ship_team
- Silent (doesn't announce)

**4. Job Assignment Override** (in `voidcrew/edits/subsystem/ticker.dm`):

Completely replaces TG's job system to:
- Spawn players on the roundstart ship
- Use ship category preferences instead of station jobs
- Handle latejoining via ship selection menu

**5. Overmap Integration**:

The overmap subsystem manages:
- Dynamic encounter spawning (planets, ruins)
- Ship tracking
- Jump mechanics

#### NOT IMPLEMENTED:

1. **Dynamic Antagonist Selection**: Voidcrew does not use SSdynamic for antag selection. The rulesets exist but:
   - No tier selection
   - No roundstart antag spawning
   - No midround antag injection
   - No latejoin antag conversion

2. **Threat Calculation**: No threat level system based on dead/alive ratio

3. **Midround Events**: No automatic spawning of blobs, xenomorphs, space dragons, etc.

4. **Station-based Objectives**:
   - Hijack shuttle (no emergency shuttle)
   - Escape to CentCom (no CentCom)
   - Station-specific steal targets

5. **Crew Victory Conditions**:
   - No "heads surviving" checks
   - No "disk secured" checks
   - No "station evacuated" status

6. **Antag Victory Conditions**:
   - No nuclear victory
   - No cult summon victory
   - No revolution victory

7. **News Reports**: No end-of-round news summaries based on mode results

#### IMPLEMENTATION IDEAS:

**1. Ship-Based Dynamic System**

Instead of station-wide threat, track per-ship threat levels:
```dm
/obj/structure/overmap/ship
    var/threat_level = 0
    var/list/active_threats = list()
```

Threats could include:
- Hostile ships nearby
- Crew members killed
- Ship damage percentage
- Active antagonists aboard

**2. Multi-Ship Rulesets**

Adapt existing rulesets for multi-crew scenarios:

| TG Ruleset | Voidcrew Adaptation |
|------------|---------------------|
| Traitor | Ship Infiltrator - spawn on one ship, objectives target another |
| Revolution | Mutiny - overthrow the captain of YOUR ship |
| Nukies | Pirate Raiders - spawn on hostile ship, raid player ships |
| Changeling | Stowaway - spawn in cryo, impersonate crew |
| Wizard | Space Wizard - spawn on magic asteroid, terrorize all ships |

**3. Ship vs Ship Mechanics**

- **Boarding Parties**: Midround event that spawns raiders on a random ship
- **Distress Signals**: Ships can call for help, attracting both rescuers and pirates
- **Trade Disputes**: Two ships have conflicting objectives involving the same cargo

**4. Overmap-Integrated Objectives**

New objective types:
- `objective/explore`: Visit X different planets
- `objective/salvage`: Collect X credits worth of salvage
- `objective/trade`: Complete trades with X different ships
- `objective/survive_jump`: Be aboard a ship that completes bluespace jump
- `objective/strand`: Prevent target's ship from jumping

**5. Ship Victory Conditions**

```dm
/obj/structure/overmap/ship/proc/check_victory()
    // Ship escaped via bluespace jump
    if(SSovermap.jump_mode == BS_JUMP_COMPLETED && ship_jumped)
        return SHIP_VICTORY_ESCAPED
    // Ship destroyed
    if(integrity <= 0)
        return SHIP_VICTORY_DESTROYED
    // Crew eliminated
    if(!is_active_team(src))
        return SHIP_VICTORY_ABANDONED
```

**6. Dynamic Events for Overmap**

Adapt midround system for space events:
- Meteor showers targeting ships
- Derelict spawns with hostile creatures
- Distress beacons from NPC ships
- Hostile NPC ships that attack

**7. Per-Ship Roundend Reports**

```dm
/datum/team/voidcrew/proc/generate_roundend_report()
    var/report = ""
    report += "=== [ship.name] ===" + "\n"
    report += "Final Crew: [length(members)]" + "\n"
    report += "Ship Status: [ship.integrity]% integrity" + "\n"
    report += "Destinations Visited: [ship.planets_visited]" + "\n"
    // Objectives for each crew antag
    for(var/datum/mind/M in members)
        for(var/datum/antagonist/A in M.antag_datums)
            report += A.roundend_report()
    return report
```

**8. Threat Level by Orbit Distance**

Use the overmap's orbital rings for natural threat scaling:
- Inner rings (near sun): More dangerous, better loot
- Outer rings: Safer, less valuable
- Event frequency increases closer to sun

**9. Jump Countdown as "Evacuation"**

The bluespace jump system already mirrors the emergency shuttle:
- `request_jump()` = Call shuttle
- `cancel_jump()` = Recall shuttle
- `initiate_jump()` = Launch point
- `BS_JUMP_COMPLETED` = Shuttle docked at CentCom

Could add objectives that trigger based on jump status:
- "Escape via bluespace jump"
- "Prevent the jump"
- "Be the last ship to jump"

#### KEY FILES:

```
TG Dynamic System:
- code/controllers/subsystem/dynamic/dynamic.dm (main SSdynamic)
- code/controllers/subsystem/dynamic/_dynamic_defines.dm (defines)
- code/controllers/subsystem/dynamic/_dynamic_ruleset.dm (base ruleset)
- code/controllers/subsystem/dynamic/_dynamic_tier.dm (tier definitions)
- code/controllers/subsystem/dynamic/dynamic_ruleset_roundstart.dm
- code/controllers/subsystem/dynamic/dynamic_ruleset_midround.dm
- code/controllers/subsystem/dynamic/dynamic_ruleset_latejoin.dm

TG Objectives:
- code/game/gamemodes/objective.dm (all objective types)
- code/game/gamemodes/objective_items.dm (steal targets)

TG Round End:
- code/__HELPERS/roundend.dm (round end helpers)
- code/controllers/subsystem/ticker.dm (round state management)

Voidcrew Gamemodes:
- voidcrew/gamemodes/game_mode.dm (check_finished override)
- voidcrew/edits/subsystem/ticker.dm (job assignment rewrite)
- voidcrew/modules/teams/_team.dm (ship team system)
- voidcrew/modules/antagonist/crewmember/crew.dm (crew antag datum)
- voidcrew/modules/overmap/code/controllers/subsystem/overmap.dm (bluespace jump)
```

### MODULES I-P ANALYSIS
**Agent:** Modules I-P
**Status:** Complete
**Date:** 2025-12-30

#### MODULE STATUS:
| Module | Purpose | Voidcrew Status | Ship Relevance |
|--------|---------|-----------------|----------------|
| instruments | Musical instruments (piano synth, songs) | INHERITED | Low - Entertainment |
| interview | New player interview questionnaire system | INHERITED | Low - Admin feature |
| jobs | Job definitions, departments, access, job experience tracking | EDITED (voidcrew/edits/jobs.dm) | HIGH - Ship roles |
| keybindings | Client keybinding system | EDITED (voidcrew/edits/keybindings.dm) | Medium - Custom ship part keybind |
| language | Language system (20+ languages: Common, Draconic, Moffic, etc.) | INHERITED | Low - RP feature |
| library | Books, bibles, skill learning, bookcases | INHERITED | Low - RP/Learning |
| lighting | Core lighting engine (sources, corners, areas) | INHERITED | Medium - Atmosphere |
| loadout | Character loadout preference system | INHERITED | Low - Cosmetic |
| logging | Game logging categories and entries | INHERITED | Low - Admin |
| lootpanel | UI panel for looting containers | INHERITED | Low - QoL |
| lost_crew | Dead body generation with backstories | INHERITED | Medium - Exploration content |
| mafia | In-game Mafia minigame | INHERITED | NA - Station entertainment |
| manufactorio | Factory automation (smelters, sorters, crafters) | INHERITED | Medium - Ship manufacturing |
| mapfluff | Map-specific flavor code (ruins, centcom) | INHERITED | Low - Map decoration |
| mapping | Map loading, templates, helpers, ruins system | INHERITED | HIGH - Dynamic encounters |
| meteors | Meteor types, waves, spawning | INHERITED | HIGH - Space hazard |
| mining | Mining equipment, ores, machines, lavaland | EDITED (voidcrew/modules/mining/) | HIGH - Resource gathering |
| mob | Core mob code (movement, say, inventory, transforms) | EDITED (voidcrew/modules/mob/) | HIGH - Core gameplay |
| mob_spawn | Corpse spawners, ghost roles | EDITED (voidcrew/modules/mob_spawn/) | Medium - Exploration content |
| mod | MODsuits (modular suits with customizable modules) | INHERITED | Medium - Equipment |
| modular_computers | Tablet/laptop systems, file system | INHERITED | Medium - Ship computing |
| movespeed | Movement speed modifiers system | INHERITED | Medium - Gameplay balance |
| NTNet | Network relay system for computers | INHERITED | HIGH - Ship comms infrastructure |
| overmap | **EMPTY IN TG** | **VOIDCREW CORE** | **CRITICAL** - Ship navigation |
| pai | Personal AI companions | INHERITED | Low - RP companion |
| paperwork | Paper, pens, fax, photocopier, stamps | EDITED (voidcrew/modules/paperwork/) | Low - Minor fax edit |
| photography | Cameras and photos | INHERITED | Low - RP feature |
| plumbing | Fluid duct system | INHERITED | Medium - Ship plumbing |
| point | Pointing at things (UI) | INHERITED | Low - QoL |
| power | **CORE POWER SYSTEMS** - SMES, cables, APCs, generators, solar, singularity, supermatter, tesla, turbine | EDITED (voidcrew/modules/power/) | **CRITICAL** - Ship power |
| procedural_mapping | Map generators with modules (terrain, flora spawning) | INHERITED | HIGH - Planet generation |
| projectiles | Guns, bullets, ammo, magazines, firing pins | INHERITED | Medium - Combat |

#### CRITICAL MODULES - DETAILED ANALYSIS:

##### OVERMAP (VOIDCREW EXCLUSIVE)
Location: `voidcrew/modules/overmap/`
This is a **completely custom Voidcrew system** - TG's overmap folder is empty.

**SSovermap Subsystem** (`code/controllers/subsystem/overmap.dm`):
- Creates 25x25 overmap grid with edge boundaries
- Spawns central star (regular or binary)
- Places planets from SSmapping.planets at random orbits
- Spawns space ruins as explorable signals
- Spawns hazard events (asteroids, radiation clouds, etc.)
- Manages bluespace jump system (request -> initiate -> complete)
- Tracks all simulated ships in `simulated_ships` list
- Dynamic encounter spawning with mapgen support

**Ship System** (`code/modules/overmap/ship.dm` - 1200+ lines):
- Links to shuttle docking ports
- Speed/velocity system with x/y thrust
- Mass calculation from shuttle turfs
- Ship health based on turf integrity (50% = destroyed)
- Fuel tracking across engines
- Ship-to-ship docking with pending request system
- Auto-deletion of abandoned ships (10 min timer)
- Crew manifest and bank account per ship
- Ship announcements and broadcasts

**Planet System** (`code/modules/overmap/planet.dm`):
- Dynamic level loading/unloading
- Mapgen integration for procedural terrain
- Weather controller support
- Reserve docking ports (2 per planet)

**Space Ruins** (`code/modules/overmap/space_ruin.dm`):
- Loads TG space ruin templates dynamically
- Dockable exploration sites
- Auto-respawn when abandoned

##### POWER SYSTEM (see dedicated Power Systems Analysis section)

##### MINING SYSTEM
Location: `code/modules/mining/`

**Core Systems:**
- Ore types and coin generation
- Mining equipment (pickaxes, drills, resonators)
- Boulder processing machinery
- Ore redemption machines (ORM)
- Silo system for ore storage
- Abandoned crates (exploration loot)
- Lavaland flora and fauna
- Shelter capsules

**Voidcrew Mining Edits:**
- `equipment/explorer_gear.dm` - Custom explorer suit variants
- `lavaland/ash_flora.dm` - Whitesands planet flora (cave fern, fire blossom, puce crystals)
- `lavaland/edits/` - Machine redemption, mining orders, necropolis chest modifications

##### NTNet SYSTEM
Location: `code/modules/NTNet/relays.dm`

**Purpose:** Quantum relay network for modular computers
- Relays enable/disable wireless network
- DoS attack vulnerability (buffer overflow crash)
- 10kW power consumption when active
- Multiple relays provide redundancy

**Ship Relevance:** HIGH - Ships need network relay for tablets/laptops

##### PROCEDURAL MAPPING
Location: `code/modules/procedural_mapping/`

**TG System:**
- mapGenerator datum coordinates mapGeneratorModules
- Modules define spawnableAtoms/spawnableTurfs with probabilities
- Cluster checking to prevent overcrowding
- Supports rectangular and circular regions

**Voidcrew Planet Generator** (`voidcrew/datums/mapgen/PlanetGenerator.dm`):
- Perlin noise for heat/humidity/height
- Biome-based terrain generation
- Cave vs overworld differentiation
- Supports: Beach, Lavaland, Icemoon, Reebe, Wasteland

##### JOBS SYSTEM EDIT
Location: `voidcrew/edits/jobs.dm`

**Modifications:**
- Added `officer` var - designates ship leadership roles
- Added `job_category` var - for ship role preferences
- `map_check()` override - validates jobs against ship template
- Jobs not in ship template lose `JOB_NEW_PLAYER_JOINABLE` flag
- Officer becomes overflow role

##### KEYBINDINGS EDIT
Location: `voidcrew/edits/keybindings.dm`

**Custom Keybind:**
- `N` key - "Take ship part" keybinding
- Allows withdrawing ship parts from database account
- Uses rarity-based part system

#### NOT IMPLEMENTED / NEEDS WORK:
| Feature | Current State | Recommendation |
|---------|---------------|----------------|
| NTNet Ship Isolation | Global network | Per-ship networks |
| Meteor Shield System | No defense | Ship-mounted point defense |
| Ship-to-Ship Communication | None | Radio/NTNet bridge |
| Mining Drone | None | Remote mining from ship |
| Dynamic Job Assignment | Ship-based | More flexible role system |

#### IMPLEMENTATION IDEAS:
1. **NTNet Per-Ship**: Each ship gets its own network with optional bridge to other ships
2. **Meteor Defense**: Link meteor system to ship integrity, add point defense turrets
3. **Remote Mining**: Mining drones that can be deployed from ship to asteroids
4. **Ship Power Dashboard**: Centralized power management console showing all ship systems
5. **Dynamic Crew Roles**: Jobs that can be assigned/reassigned mid-round based on ship needs
6. **Manufactorio Ship Factory**: Pre-built factory setups for common ship manufacturing

#### KEY FILES:
```
OVERMAP (Voidcrew Exclusive):
- voidcrew/modules/overmap/code/controllers/subsystem/overmap.dm (SSovermap)
- voidcrew/modules/overmap/code/modules/overmap/ship.dm (Ship datum)
- voidcrew/modules/overmap/code/modules/overmap/planet.dm (Planet system)
- voidcrew/modules/overmap/code/modules/overmap/space_ruin.dm (Ruins)
- voidcrew/modules/overmap/code/modules/overmap/ship_damage.dm (Integrity)

MINING:
- code/modules/mining/ (Full TG system)
- voidcrew/modules/mining/equipment/explorer_gear.dm
- voidcrew/modules/mining/lavaland/ash_flora.dm

PROCEDURAL:
- code/modules/procedural_mapping/ (TG base)
- voidcrew/datums/mapgen/PlanetGenerator.dm (Custom planet gen)

JOBS:
- code/modules/jobs/ (TG jobs)
- voidcrew/edits/jobs.dm (Ship job integration)

MOB SPAWN:
- code/modules/mob_spawn/ (TG base)
- voidcrew/modules/mob_spawn/corpses/wasteland_corpses.dm (Custom corpses)
```

---

### MODULES Q-Z ANALYSIS
**Agent:** Modules Q-Z
**Status:** Complete
**Date:** 2025-12-30

#### MODULE STATUS:
| Module | Purpose | Voidcrew Status | Ship Relevance |
|--------|---------|-----------------|----------------|
| reagents | Chemistry system, reagent containers, dispensers, withdrawal | MINOR EDITS (custom reagents) | Medium - medicine/toxins work anywhere |
| recycling | Conveyor belts, disposal system, sorting | INHERITED | Medium - waste management on ships |
| religion | Chaplain mechanics, sects, rites, structures | INHERITED | Low - flavor content |
| requests | Request console system for inter-department comms | INHERITED | Medium - inter-ship requests possible |
| research | Techweb, R&D consoles, destructive analyzer, stock parts, xenobiology | HEAVILY EDITED | High - survey scanners, nanites, shuttle tech nodes |
| security_levels | Keycard authentication, alert levels (blue/red/delta) | INHERITED | Low - station-focused concept |
| ship_purchase | **VOIDCREW CUSTOM** Ship catalog UI, economy database | VOIDCREW NEW | Critical - core ship purchasing |
| shuttle | Docking ports, shuttle consoles, mobile ports, events | HEAVILY EDITED | Critical - ships ARE shuttles |
| spatial_grid | Cell tracking for proximity/range optimization | INHERITED | High - overmap proximity uses this |
| spells | Magic spell system for wizards | INHERITED | Low - antagonist content |
| station_goals | Round objectives (BSA, DNA vault, meteor shield) | NOT ADAPTED | Low - needs ship goals equivalent |
| surgery | Medical procedures, organ manipulation | MINOR EDITS (dissection tiers) | Medium - works on ships |
| tgchat | Chat message handling, to_chat system | INHERITED | Low - core infrastructure |
| tgs | TGS (TG Station Server) integration | INHERITED | Low - server infrastructure |
| tgui | React UI framework backend | INHERITED | Low - core infrastructure |
| tgui_input | TGUI input dialogs (alerts, lists, numbers) | INHERITED | Low - core infrastructure |
| tgui_panel | TGUI panel/window management | INHERITED | Low - core infrastructure |
| tooltip | Mouse hover tooltips | INHERITED | Low - core UI |
| transport | Trams, elevators, linear transport systems | INHERITED | Low - large station systems |
| tutorials | New player tutorial system | INHERITED | Medium - needs ship-specific tutorials |
| unit_tests | Automated testing framework | INHERITED | Low - development infrastructure |
| uplink | Traitor uplink items, purchasing system | INHERITED | Medium - antagonist content |
| vehicles | ATVs, bicycles, mechs, wheelchairs, scooters | MINOR EDITS (keyless ATV) | Medium - usable in hangars |
| vending | Vending machines for all departments | MINOR EDITS (marine vendors) | Medium - ship supply |
| visuals | Visual render steps/effects | INHERITED | Low - core rendering |
| wiremod | Programmable circuit system | INHERITED | High - automation potential |
| zombie | Zombie infection organs/mechanics | INHERITED | Low - antagonist content |

#### KEY VOIDCREW MODIFICATIONS:

**SHUTTLE MODULE (CRITICAL - HEAVILY MODIFIED):**
Location: `voidcrew/modules/shuttle/`

| File | Purpose |
|------|---------|
| emergency.dm | DISABLES emergency shuttle calling |
| engine/shuttle_engine.dm | Custom ship engine base class with fuel/burn mechanics |
| engine/fuel.dm, electric.dm, void.dm, liquid.dm | Various engine types |
| helm/_helm.dm | Ship helm console with full overmap integration |
| ship_parts/ | Ship spawners, user preferences |
| construction/ | Ship construction console/drone system |
| survey/ | Orbital survey console for research points |

**Helm Console Features:**
- Ship navigation and heading control
- Engine monitoring and fuel display
- Bluespace jump calibration (3 min charge, removes ship from round)
- Overmap object interaction
- Ship renaming with cooldowns
- Crew authorization checks
- Auto-repair state tracking

**Engine System:**
- Base `/obj/machinery/power/shuttle_engine/ship` type
- `burn_engine()` proc with mass-based fuel consumption
- Enable/disable toggle per engine
- Fuel tracking via `return_fuel()` and `return_fuel_cap()`
- Mass fuel multiplier calculation

**RESEARCH MODULE (HEAVILY MODIFIED):**
Location: `voidcrew/modules/research/`

| File | Purpose |
|------|---------|
| techweb_nodes.dm | Custom tech nodes: shuttle tech, survey scanners, nanites, sleeper |
| survey_scanner.dm | Machine that generates research points from power |
| server.dm | Research server modifications |
| machinery_rnd.dm | R&D console tweaks |
| edits/ | Experiments, production, techweb modifications |
| designs/ | Autolathe, cargo, medical, sleeper designs |

**New Techweb Nodes:**
- `basic_shuttle_tech` - Plasma/ion engines, helm console, ship construction (10000 pts)
- `exp_shuttle_tech` - Expulsion engines (5000 pts)
- `survey_scanner` - Survey scanner machine (1000 pts)
- `survey_console` - Orbital survey console (1000 pts)
- `survey_console_advanced/superior/elite` - Progressive upgrades with survey requirements (5k/10k/20k pts)
- Full nanite programming tree (basic, smart, mesh, bio, neural, synaptic, harmonic, military, hazard)
- `sleepertech` - Sleeper construction (5000 pts)

**Survey Console System:**
Location: `voidcrew/modules/shuttle/survey/`
- Orbital survey console for scanning celestial objects
- Generates research points and credits
- Progressive upgrade tiers with survey object requirements (planets, nebulas, storms)
- Data disk system for storing/sharing survey data
- Ship docking integration
- Mapping features (object/mob sight upgrades at higher tiers)

**SHIP_PURCHASE MODULE (VOIDCREW NEW):**
Location: `code/modules/ship_purchase/`

| File | Purpose |
|------|---------|
| ship_catalog_ui.dm | TGUI ship browsing/purchasing interface |
| ship_economy_database.dm | Ship pricing and unlock system |
| transaction_helpers.dm | Purchase transaction processing |
| admin/ | Admin ship spawning tools |

Features:
- Lazy-loaded ship catalog from voidcrew shuttle templates
- Faction filtering
- Crew capacity display
- Unlock cost system
- Preview images

**VENDING (MINOR EDITS):**
Location: `voidcrew/modules/vending/`
- Marine vendor machines with gun vouchers
- Syndicate and SolGov variants
- Weapon selection via radial menu (M-90gl, Sniper, C-20r, Bulldog)

**SURGERY (MINOR EDITS):**
Location: `voidcrew/modules/surgery/`
- Advanced/Superior/Elite dissection tiers
- Research point values scaled by species rarity (monkeys /5, abductors x4, aliens x10)
- Faster surgery times at higher tiers (8s -> 4s -> 1s)

**VEHICLES (MINOR EDITS):**
Location: `voidcrew/modules/vehicles/`
- Keyless beach ATV variant

#### NOT IMPLEMENTED/NEEDS WORK:

| Feature | Current State | Recommendation |
|---------|---------------|----------------|
| Station Goals | TG station goals are station-centric | Create Ship Goals - exploration targets, survey quotas |
| Security Levels | Designed for single station | Per-ship alert levels or faction-wide alerts |
| Transport (Trams) | Large station transport | N/A for ships (too small) |
| Tutorials | Generic TG tutorials | Ship-specific tutorials for helm, engines, overmap |
| Request Console | Inter-department on station | Inter-ship request/trade system |
| Emergency Shuttle | Disabled but not replaced | Consider escape pod system |

#### IMPLEMENTATION IDEAS:

**Ship Goals System:**
- Survey X planets
- Collect X materials from mining
- Trade with X ships
- Explore X sectors
- Research X points worth of discoveries

**Per-Ship Alert Levels:**
- Green: Normal operations
- Yellow: Potential hostiles nearby
- Red: Under attack / emergency
- Delta: Abandon ship

**Inter-Ship Communications:**
- Trade request console
- Distress beacon system
- Coalition broadcast network

#### KEY FILES:
```
Shuttle (Critical):
- voidcrew/modules/shuttle/helm/_helm.dm (ship control)
- voidcrew/modules/shuttle/engine/shuttle_engine.dm (base engine)
- voidcrew/modules/shuttle/emergency.dm (disables evacuation)

Research:
- voidcrew/modules/research/techweb_nodes.dm (custom tech tree)
- voidcrew/modules/research/survey_scanner.dm (point generation)
- voidcrew/modules/shuttle/survey/survey_computer.dm (orbital scanning)

Ship Purchase:
- code/modules/ship_purchase/ship_catalog_ui.dm (catalog interface)
- code/modules/ship_purchase/ship_economy_database.dm (pricing)

Wiremod (Inherited but useful):
- code/modules/wiremod/core/component.dm (base component)
- code/modules/wiremod/components/ (all component types)

Uplink (Inherited):
- code/modules/uplink/uplink_items/ (traitor items by category)
```

---

### CAMERA/AI/SILICON ANALYSIS
**Agent:** AI Systems (a1ae3ae)
**Status:** Complete
**Date:** 2025-12-30

#### TG AI SYSTEMS:
| System | Purpose | Ship Compatibility |
|--------|---------|-------------------|
| GLOB.cameranet | Global singleton managing all cameras | STATION-ONLY - uses global datum |
| /datum/camerachunk | 16x16 tile chunks for visibility | Chunk-based, station z-level focused |
| /mob/living/silicon/ai | Main AI mob type | STATION-ONLY - expects station infrastructure |
| /mob/eye/camera/remote | AI's roaming camera eye | Network-locked by default |
| /mob/living/silicon/robot | Cyborg mobs | Can work with ships but law-synced to station AI |
| /mob/living/silicon/pai | Personal AI companions | SHIP-COMPATIBLE - local to holder |

#### CAMERA NETWORK ARCHITECTURE:
**Global Camera Net (GLOB.cameranet):**
- Single global /datum/cameranet manages ALL cameras across all z-levels
- Cameras register on Initialize(), tracked in GLOB.cameranet.cameras list
- Uses 16x16 tile chunks (/datum/camerachunk) for visibility calculations
- Static overlay system for areas cameras cannot see

**Camera Networks (String-based):**
- CAMERANET_NETWORK_SS13 = "ss13" (Main station)
- CAMERANET_NETWORK_MINE, RD, VAULT, AI_CORE, MEDBAY, ENGINE, etc.

**Per-Ship Camera Handling (connect_to_shuttle):**
Cameras and consoles get network prefixed with shuttle_id (e.g., "ship_1_ss13").
This provides basic per-ship camera isolation.

#### AI EYE/VISION SYSTEM:
- AI Eye (/mob/eye/camera/remote) uses cameranet visibility
- use_visibility flag can disable network checking
- relay_speech enables hearing via cameras
- static_visibility_range controls static display

#### AI CAPABILITIES:
**Standard Powers:** Camera Network, Door Control, Power Control, Intercoms, Turret Control, Borg Connection, Law Sync

**Malf AI Modules (19 total):**
- Doomsday Device (130), Hostile Lockdown (30), Machine Override (30)
- Destroy RCDs (25), Machine Overload (20), Blackout (15)
- Robotic Factory (100), Air Alarm Override (50), Thermal Sensor Override (25)
- Emergency Lights (10), Reactivate Cameras (10), Upgrade Cameras (35)
- Turret Upgrade (30), Enhanced Surveillance (30), Mech Domination (30)
- Voice Changer (20), Targeted Emag (20), Rolling Servos (10), Vendor Tilting (15)

#### AI LAW SYSTEM:
**Law Structure:** zeroth > ion > hacked > inherent > supplied
**Default Lawsets:** Asimov, Crewsimov, Corporate, Robocop, Paladin, Tyrant, Antimov, Custom

#### SILICON ROLES:
**AI:** Central station AI with camera network, borg control, law sync
**Cyborg:** Mobile silicon with tool modules, law-synced to AI
**pAI:** Personal AI with limited range, software abilities (RAM-based)

#### VOIDCREW STATUS:
| Feature | Status | Notes |
|---------|--------|-------|
| Camera network | PARTIAL | Uses TG system with shuttle prefixes |
| Ship Construction Drone | CUSTOM | Disables camera visibility |
| AI Core | NOT ADAPTED | Station-focused |
| Cyborgs | INHERITED | Needs ship-specific AI |
| pAI | INHERITED | Works well for ships |
| Malf AI | NOT ADAPTED | Assumes station |

**Ship Construction Drone disables camera visibility:**
/mob/eye/camera/remote/base_construction/ship has use_visibility = FALSE

#### IMPLEMENTATION IDEAS:
1. **Short-term:** pAI works great for ships
2. **Medium-term:** Use shuttle camera prefix system
3. **Long-term:** /mob/living/silicon/ai/ship with local cameranet

#### KEY FILES:
- code/modules/mob/living/silicon/ai/freelook/cameranet.dm
- code/game/machinery/camera/camera.dm
- code/__DEFINES/cameranets.dm
- code/modules/mob/living/silicon/ai/ai.dm
- code/datums/ai_laws/ai_laws.dm
- code/modules/antagonists/malf_ai/malf_ai_modules.dm
- code/modules/pai/pai.dm
- voidcrew/modules/shuttle/construction/construction_drone.dm

---

### EVENTS SYSTEM ANALYSIS
**Agent:** Events
**Status:** Complete
**Date:** 2025-12-30

#### TG EVENT CATEGORIES:
| Category | Description | Count |
|----------|-------------|-------|
| EVENT_CATEGORY_AI | AI-related events (ion storm) | 1 |
| EVENT_CATEGORY_ANOMALIES | Anomaly spawns (flux, gravity, bluespace, etc.) | 10+ |
| EVENT_CATEGORY_BUREAUCRATIC | Administrative events (cargo, market, shuttle loan) | 5 |
| EVENT_CATEGORY_ENGINEERING | Power/SM events (grid check, supermatter surge) | 4 |
| EVENT_CATEGORY_ENTITIES | Creature spawns (carp, vines, portal storm) | 8 |
| EVENT_CATEGORY_FRIENDLY | Positive events (sentience, aurora caelus) | 3 |
| EVENT_CATEGORY_HEALTH | Medical events (disease outbreak, heart attack) | 4 |
| EVENT_CATEGORY_HOLIDAY | Holiday-specific events | 5 |
| EVENT_CATEGORY_INVASION | Hostile events (lone operative, dynamic tweak) | 2 |
| EVENT_CATEGORY_JANITORIAL | Cleanup events (vent clog, scrubber overflow) | 3 |
| EVENT_CATEGORY_SPACE | Space hazards (meteors, radiation storm, immovable rod) | 8 |
| EVENT_CATEGORY_WIZARD | Wizard summon events (23 subtypes) | 23 |

#### ALL TG EVENTS (Core Files):
**Space Threats:**
- Meteor Wave (Normal/Threatening/Catastrophic/Meaty/Dust)
- Immovable Rod
- Radiation Storm
- Stray Meteor

**Anomalies (10 types):**
- Flux, Bluespace, Dimensional, Ectoplasm, Gravity
- Hallucination, Bioscrambler, Pyro, Vortex, Placer

**Entities:**
- Carp Migration
- Space Vines (Kudzu)
- Portal Storm (Syndicate/Narsie)
- Mice Migration

**Health:**
- Disease Outbreak (Classic/Advanced)
- Heart Attack
- Brain Trauma
- Fake Virus (announcement only)

**Engineering:**
- Grid Check (power failure)
- Supermatter Surge (and Poly variant)
- Radiation Leak
- Gravity Generator Blackout

**Bureaucratic:**
- Stray Cargo Pod (Normal/Syndicate)
- Shuttle Loan
- Market Crash
- Shuttle Catastrophe
- Shuttle Insurance

**AI/Silicon:**
- Ion Storm (modifies AI laws)

**Communication:**
- Communications Blackout
- Camera Failure
- False Alarm (fake announcement)

**Ghost Role Events:**
- Sentience (animal gains intelligence)
- Lone Operative (nuke op)

**Minor Events:**
- Dust (space dust)
- Bureaucratic Error
- Grey Tide
- Electrical Storm
- Mass Hallucination
- Processor Overload
- Aurora Caelus
- Dynamic Tweak

**Wizard Events (23 types):**
- Aid, Blobies, Cursed Items, Department Revolt
- Embeddies, Fake Explosion, Ghost, Greentext
- Identity Spoof, Imposter, Invincible, Lava
- Madness, Magical Rain, Magicarp, Object Rain
- Petsplosion, Race, RPG Loot, RPG Titles
- Shuffle, Summons, Tower of Babel

#### EVENT SYSTEM MECHANICS:

**SSevents Subsystem** (code/controllers/subsystem/events.dm):
- frequency_lower = 2.5 MINUTES (min time between events)
- frequency_upper = 7 MINUTES (max time between events)
- scheduled = 0 (next event time)
- wizardmode = FALSE (enable wizard events)

**Event Control Datum** (code/modules/events/_event.dm):
- weight = 10 (selection weight, higher = more likely)
- earliest_start = 20 MINUTES (round time before can occur)
- min_players = 0 (required player count)
- max_occurrences = 20 (max times can happen naturally)
- holidayID = empty (holiday restriction)
- wizardevent = FALSE (wizard-only event)
- map_flags = NONE (EVENT_SPACE_ONLY, EVENT_PLANETARY_ONLY)

**Population Scaling:**
- Events check get_active_player_count(alive_check=TRUE, afk_check=TRUE, human_check=TRUE)
- Events set min_players to require certain population
- Example: Meteor Wave requires 15+ players, Disease Advanced requires 35+

**Weight Examples (Higher = More Common):**
| Event | Weight | Min Players | Earliest Start |
|-------|--------|-------------|----------------|
| Dust (space dust) | 200 | 0 | 0 min |
| Camera Failure | 100 | 0 | 20 min |
| Gravity Blackout | 30 | 0 | 20 min |
| Brain Trauma | 25 | 13 | 20 min |
| Stray Cargo | 20 | 0 | 10 min |
| Heart Attack | 20 | 40 | 20 min |
| Ion Storm | 15 | 2 | 20 min |
| Carp Migration | 15 | 12 | 10 min |
| Space Vines | 15 | 10 | 20 min |
| Anomaly Base | 15 | 1 | 20 min |
| Meteor Wave | 4 | 15 | 25 min |
| Portal Storm | 2 | 15 | 30 min |

**Event Flow:**
1. SSevents fires every tick
2. checkEvent() checks if scheduled time reached
3. spawnEvent() picks weighted random from eligible events
4. preRunEvent() does preflight checks, notifies admins
5. run_event() creates event datum and starts processing
6. Event datum calls setup(), announce(), start(), tick(), end()

#### VOIDCREW STATUS:

**Events Inherited (Unmodified):**
- All TG events work as-is
- No Voidcrew-specific event modifications found in codebase
- Events use is_station_level() and GLOB.the_station_areas checks

**Voidcrew Overmap Events:**
Location: voidcrew/modules/overmap/code/modules/overmap/events.dm

| Event Type | Spread Chance | Chain Rate | Effect |
|------------|---------------|------------|--------|
| Asteroid Storm (minor) | 50% | 3 | Mineral deposits |
| Asteroid Storm (moderate) | 50% | 4 | More minerals |
| Asteroid Storm (major) | 25% | 6 | Diamond/Uranium/Bluespace |
| Ion Storm (minor) | 20% | 1 | Light EMP |
| Ion Storm (moderate) | 20% | 2 | Medium EMP |
| Ion Storm (major) | 20% | 4 | Heavy EMP |
| Electrical Storm (minor) | 40% | 2 | Light electrical |
| Electrical Storm (moderate) | 30% | 3 | Medium electrical |
| Electrical Storm (major) | 15% | 6 | Heavy electrical |
| Nebula | 75% | 8 | Plasma gas, blocks vision |

These overmap events are tile hazards ships can fly through, NOT round events.

#### NOT IMPLEMENTED FOR SHIPS:

**Events Using is_station_level() (Will Not Work on Ships):**
- Disease Outbreak candidate checks
- Sentience mob priority checks
- Anomaly area placement
- Carp migration path finding
- Stray cargo area selection
- Portal storm turf selection
- Meteor targeting
- Earthquake effects

**Events Using GLOB.the_station_areas (Will Not Work on Ships):**
- Anomaly placer (generateAllowedAreas())
- Stray cargo (find_event_area())
- Carp migration (pick_carp_migration_points())
- Space vines spawning

**Events Using get_random_station_turf() (Will Not Work on Ships):**
- Immovable rod targeting
- Portal storm spawn points
- Mass hallucination

**Events Using Station-Specific Machinery:**
- Supermatter Surge (checks GLOB.main_supermatter_engine)
- Grid Check (station power grid)
- Gravity Blackout (station gravity gen)

#### IMPLEMENTATION IDEAS FOR VOIDCREW:

**1. Ship-Aware Event System:**
- Replace is_station_level() checks with ship area checks
- is_ship_level(z_level) proc to check SSovermap.simulated_ships

**2. Per-Ship Event Targeting:**
- get_random_ship_turf(target_ship) proc
- Use mapzone.z_levels for ship turf selection

**3. Overmap Event Triggers:**
- When ship enters asteroid storm tile, spawn meteors targeting ships z-level
- chain_rate controls meteor count

**4. Event Population Scaling:**
- Count players on specific ships, not global
- Small crew ships get fewer/lighter events
- Flagship gets normal event weight

**5. Multi-Ship Event Distribution:**
- Rotate events between active ships
- pick_target_ship() proc for event targeting

**6. Ship-Specific Events to Create:**
- Hull breach from overmap hazards
- Pirate encounter (boarding party)
- Distress beacon rescue mission
- Engine malfunction
- Life support failure
- FTL drive cooldown events

**7. Disable Inappropriate Events:**
- shuttle_loan - ships do not have cargo shuttle
- supermatter_surge - unless ship has SM engine
- gravity_blackout - ship-specific gravity
### MOBS/SPECIES ANALYSIS
**Agent:** Mobs/Species (a171cd0)
**Status:** Complete
**Date:** 2025-12-30

#### MOB HIERARCHY OVERVIEW:

The TG mob system follows this inheritance hierarchy:
```
/mob (base mob)
+-- /mob/dead
|   +-- /mob/dead/new_player (lobby)
|   +-- /mob/dead/observer (ghost)
+-- /mob/living
|   +-- /mob/living/basic (modern simple NPCs)
|   +-- /mob/living/simple_animal (legacy NPCs)
|   |   +-- /mob/living/simple_animal/bot (service bots)
|   |   +-- /mob/living/simple_animal/hostile (combat NPCs)
|   +-- /mob/living/silicon
|   |   +-- /mob/living/silicon/ai (station AI)
|   |   +-- /mob/living/silicon/robot (cyborgs)
|   +-- /mob/living/carbon
|       +-- /mob/living/carbon/alien (xenomorphs)
|       +-- /mob/living/carbon/human (playable species)
+-- /mob/eye (remote viewing)
```

#### PLAYABLE SPECIES:

| Species | ID | Key Features | Roundstart | Subspecies |
|---------|-----|--------------|------------|------------|
| **Human** | human | Skintones, payday_modifier 1.1, Asimov protection | YES | - |
| **Felinid** | felinid | Cat ears/tail, catlike grace, sound sensitivity, hydrophobic | YES | - |
| **Lizardperson** | lizard | Cold-blooded, heat tolerant, cold vulnerable, digitigrade legs, L-type blood | YES | Ashwalker, Silverscale |
| **Moth** | moth | Wings (0g flight), eats cloth, weak to fire/flyswatters, bright light sensitivity | YES | - |
| **Ethereal** | ethereal | Energy-based, glows, feeds on electricity, agender, crystal heart revival | YES | Lustrous |
| **Plasmaman** | plasmaman | Breathes plasma, ignites in oxygen, rad immune, geneless, needs envirosuit | YES | - |
| **Flyperson** | fly | Bug eyes (flash from all angles), regurgitate eating, weird organs | NO | - |
| **Jellyperson** | jelly | Toxin blood, regenerate limbs, consume limbs when starving, slime faction | NO | Slimeperson, Luminescent, Stargazer |
| **Podperson** | pod | Plant-based, photosynthesis potential | NO | - |
| **Android** | android | Robotic humanoid, synthetic traits | NO | - |
| **Skeleton** | skeleton | No blood, no gender, undead | NO | - |
| **Zombie** | zombie | Undead, various infection types | NO | Infectious, Krokodil |
| **Vampire** | vampire | Blood-drinking, sun vulnerability | NO | - |
| **Shadow** | shadow | Light vulnerability, teleportation | NO | Nightmare |
| **Dullahan** | dullahan | Detached head, can throw head | NO | - |
| **Golem** | golem | Mineral-based, various material types | NO | - |
| **Ghost** | ghost | Spectral species for ghost roles | NO | - |
| **Snail** | snail | Shell protection, slow movement | NO | - |
| **Mushroom** | mush | Fungal-based species | NO | - |

#### SPECIES TRAITS SYSTEM:

Species define traits via inherent_traits list. Common trait categories:
- **Biological**: TRAIT_MUTANT_COLORS, TRAIT_USES_SKINTONES, TRAIT_AGENDER, TRAIT_NOBLOOD
- **Immunity**: TRAIT_VIRUSIMMUNE, TRAIT_RADIMMUNE, TRAIT_PIERCEIMMUNE, TRAIT_UNHUSKABLE
- **Environmental**: TRAIT_NOBREATH, TRAIT_RESISTCOLD, TRAIT_RESISTHIGHPRESSURE, TRAIT_RESISTLOWPRESSURE
- **Behavior**: TRAIT_CATLIKE_GRACE, TRAIT_WATER_HATER, TRAIT_HATED_BY_DOGS
- **DNA/Genetics**: TRAIT_GENELESS, TRAIT_NO_DNA_COPY, TRAIT_NO_PLASMA_TRANSFORM

#### BODY PARTS SYSTEM:

Location: code/modules/surgery/bodyparts/

| Body Zone | Constant | Held Index |
|-----------|----------|------------|
| Head | BODY_ZONE_HEAD | 0 |
| Chest | BODY_ZONE_CHEST | 0 |
| Left Arm | BODY_ZONE_L_ARM | 1 (left hand) |
| Right Arm | BODY_ZONE_R_ARM | 2 (right hand) |
| Left Leg | BODY_ZONE_L_LEG | 0 |
| Right Leg | BODY_ZONE_R_LEG | 0 |

**Bodypart Features:**
- biological_state - Determines wound types (BIO_STANDARD_UNJOINTED)
- bodytype - Surgery compatibility (BODYTYPE_ORGANIC, BODYTYPE_ROBOTIC)
- bodyshape - Clothing compatibility (BODYSHAPE_HUMANOID)
- limb_id - Species-specific sprite lookup
- brute_dam/burn_dam - Localized damage tracking
- max_damage - Per-limb damage cap
- wounds - List of wound datums affecting the limb
- embedded_objects - Items stuck in the limb

**Species-specific bodyparts:**
- Lizard: /obj/item/bodypart/*/lizard
- Moth: /obj/item/bodypart/*/moth
- Ethereal: /obj/item/bodypart/*/ethereal
- Plasmaman: /obj/item/bodypart/*/plasmaman
- Fly: /obj/item/bodypart/*/fly
- Jelly: /obj/item/bodypart/*/jelly

#### ORGANS SYSTEM:

Location: code/modules/surgery/organs/

| Organ Slot | Default Type | Special Species Variants |
|------------|--------------|-------------------------|
| Brain | /obj/item/organ/brain | Felinid, Lustrous (with traumas) |
| Heart | /obj/item/organ/heart | Ethereal (crystal core), Fly, null for Plasmaman |
| Lungs | /obj/item/organ/lungs | Plasmaman (plasma), Ethereal, Slime, Lavaland |
| Eyes | /obj/item/organ/eyes | Lizard, Moth, Fly, Jelly |
| Ears | /obj/item/organ/ears | Felinid (cat ears) |
| Tongue | /obj/item/organ/tongue | Lizard, Moth, Ethereal, Fly, Jelly, Cat |
| Liver | /obj/item/organ/liver | Plasmaman (bone), Fly, Golem, Skeleton |
| Stomach | /obj/item/organ/stomach | Ethereal, Fly, Plasmaman (bone), Golem |
| Appendix | /obj/item/organ/appendix | Fly, null for Plasmaman |

**External/Mutant Organs:**
- Tails: Cat, Lizard (various styles)
- Wings: Moth (functional flight)
- Horns, Frills, Snout, Spines: Lizard accessories
- Antennae: Moth

#### GHOST/OBSERVER SYSTEM:

Location: code/modules/mob/dead/observer/

Features:
- See invisible (SEE_INVISIBLE_OBSERVER)
- Flying movement
- Optional ghost light
- Orbit targets (follow mobs/objects)
- Ghost HUD flags (data HUDs, vision modes)
- Hair/facial hair overlays from death body
- Deadchat access
- Ghost menu (spawners, minigames)

Ghost HUDs available:
- GHOST_DATA_HUDS - Security/medical data
- GHOST_VISION - Ghost vision
- GHOST_HEALTH - Health overlay
- GHOST_CHEM - Chemical overlay
- GHOST_GAS - Atmosphere overlay

#### SILICON SYSTEM:

Location: code/modules/mob/living/silicon/

**AI (/mob/living/silicon/ai):**
- Laws datum for behavior rules
- Camera network access
- Remote door control
- Announcement capabilities
- Built-in camera for selfies

**Cyborg (/mob/living/silicon/robot):**
- Module-based equipment
- Power cell dependency
- Law inheritance from AI
- Locked/unlocked states

Silicon traits:
- TRAIT_ADVANCEDTOOLUSER - Can use tools
- TRAIT_LITERATE - Can read
- TRAIT_MADNESS_IMMUNE - No insanity
- TRAIT_MARTIAL_ARTS_IMMUNE - No martial arts
- TRAIT_SILICON_ACCESS - ID-less door access
- TRAIT_NO_SLIP_ALL - Never slips

#### NPC AI SYSTEM:

Location: code/datums/ai/

**AI Controller Architecture:**
- /datum/ai_controller - Main controller datum
- Blackboard system for knowledge storage
- Planning subtrees for behavior prioritization
- Behavior cooldowns
- Movement targeting
- Idle behaviors when no actions planned

**Basic Mob System (/mob/living/basic):**
- Modern replacement for simple_animal
- Uses AI controller system
- More modular behavior trees

**Simple Animal System (/mob/living/simple_animal):**
- Legacy NPC system
- Built-in AI via vars (hostile, retaliate, wander)
- Still used for many creatures

Hostile NPC features:
- attack_same - Attack same faction
- ranged - Ranged attacks
- rapid - Fast attack rate
- retreat_distance - Kiting behavior
- minimum_distance - Keep distance from target

#### VOIDCREW MODIFICATIONS:

| File | Purpose | Status |
|------|---------|--------|
| voidcrew/modules/mob/mob_helpers.dm | Dissection trait examine text | MINOR ADDITION |
| voidcrew/edits/mobs/new_player.dm | Ship selection latejoin system | MAJOR OVERRIDE |
| voidcrew/modules/mob/living/simple_animal/corpse.dm | Corpse handling | MINOR ADDITION |
| voidcrew/modules/mob/living/simple_animal/friendly/*.dm | Beach/ocean creatures | NEW CREATURES |
| voidcrew/modules/mob/living/simple_animal/hostile/*.dm | Various hostile mobs | NEW CREATURES |
| voidcrew/modules/mob/living/simple_animal/slime/slime.dm | Slime modifications | MINOR EDIT |

**Voidcrew New Player System:**
The new_player mob is heavily modified for Voidcrew ship-based gameplay:
- select_ship() - TGUI ship selection menu
- AttemptSpawnOnShip() - Spawn on selected ship with job
- Ship catalog integration for purchasing new ships
- Custom slot loadout application
- Ship manifest injection

**Voidcrew Hostile Mobs Added:**
- Beach/jungle creatures
- Mining mobs
- Wasteland creatures
- Pirates

**Voidcrew Friendly Mobs Added:**
- Beach carp (friendly variant)
- Sea crystals
- Various decorative creatures

#### MISSING/NEEDS WORK:

| Feature | Status | Notes |
|---------|--------|-------|
| Species whitelist config | INHERITED | Uses TG config system |
| Ship-specific species | NOT IMPLEMENTED | No species tied to ships |
| Custom species creation | NOT IMPLEMENTED | Would require DNA/genetics work |
| Species trait inheritance | INHERITED | TG system works |
| Ghost ship spawning | PARTIAL | Can observe but limited ghost roles |
| NPC crew members | NOT IMPLEMENTED | No AI-controlled crewmates |
| Pet adoption system | NOT IMPLEMENTED | No ship pets with ownership |
| Hireable NPCs | NOT IMPLEMENTED | No merchant/contractor NPCs |

#### KEY FILES:

TG Species System:
- code/modules/mob/living/carbon/human/_species.dm (base species datum)
- code/modules/mob/living/carbon/human/species_types/*.dm (individual species)
- code/__DEFINES/mobs.dm (SPECIES_* constants)
- code/__DEFINES/DNA.dm (species perks system)

TG Body Parts:
- code/modules/surgery/bodyparts/_bodyparts.dm (base bodypart)
- code/modules/surgery/bodyparts/species_parts/*.dm (species-specific parts)
- code/modules/surgery/bodyparts/robot_bodyparts.dm (prosthetics)

TG Organs:
- code/modules/surgery/organs/_organ.dm (base organ)
- code/modules/surgery/organs/internal/*.dm (internal organs)
- code/modules/surgery/organs/external/*.dm (external organs like tails)

TG Mob Types:
- code/modules/mob/mob.dm (base mob)
- code/modules/mob/living/living.dm (living mob)
- code/modules/mob/dead/observer/observer.dm (ghost)
- code/modules/mob/living/silicon/silicon.dm (AI/cyborg base)
- code/modules/mob/living/basic/basic.dm (modern NPCs)
- code/modules/mob/living/simple_animal/simple_animal.dm (legacy NPCs)

TG AI System:
- code/datums/ai/_ai_controller.dm (main controller)
- code/datums/ai/_ai_behavior.dm (behavior base)
- code/datums/ai/basic_mobs/*.dm (mob-specific AI)

Voidcrew Mob Changes:
- voidcrew/edits/mobs/new_player.dm (ship selection override)
- voidcrew/modules/mob/mob_helpers.dm (minor helpers)
- voidcrew/modules/mob/living/simple_animal/*.dm (new creatures)

---

### MEDICAL/SURGERY ANALYSIS
**Agent:** Medical
**Status:** Complete
**Date:** 2025-12-30
### ITEMS/EQUIPMENT ANALYSIS
**Agent:** Items (a5c882a)
**Status:** Complete
**Date:** 2025-12-30

#### TG ITEM SYSTEM OVERVIEW:

| Category | File Count | Key Locations |
|----------|------------|---------------|
| **Items (Base)** | 372 files | `code/game/objects/items/` |
| **Structures** | 145 files | `code/game/objects/structures/` |
| **Guns** | 35 files | `code/modules/projectiles/guns/` |
| **Clothing** | 14 directories | `code/modules/clothing/` |

#### KEY ITEM CATEGORIES:

**WEAPONS:**

| Type | Examples | Location |
|------|----------|----------|
| Melee | Chain of Command, Sabres, Synthetic Arm Blade, Batons | `code/game/objects/items/melee/` |
| Energy Melee | Energy Swords, Stunbatons | `code/game/objects/items/melee/energy.dm` |
| Ballistic Guns | Pistols, Shotguns, Rifles, SMGs, Revolvers | `code/modules/projectiles/guns/ballistic/` |
| Energy Guns | Lasers, E-guns, Pulse rifles, Kinetic Accelerators | `code/modules/projectiles/guns/energy/` |
| Magic Weapons | Wands, Staves, Arcane Barrage | `code/modules/projectiles/guns/magic/` |
| Special | Syringe Gun, Medbeam, Blastcannon, Hook Gun | `code/modules/projectiles/guns/special/` |
| Grenades | Frag, Flashbang, Smoke, EMP, Chem grenades, C4 | `code/game/objects/items/grenades/` |

**TOOLS:**

| Tool | Purpose | Location |
|------|---------|----------|
| Crowbar | Prying, deconstruction | `tools/crowbar.dm` |
| Screwdriver | Panel access | `tools/screwdriver.dm` |
| Welding Tool | Metal work, repairs | `tools/weldingtool.dm` |
| Wirecutters | Cable work | `tools/wirecutters.dm` |
| Wrench | Anchoring, pipes | `tools/wrench.dm` |
| Multitool | Wire/machine diagnostics | `devices/multitool.dm` |
| RCD Variants | Rapid construction (9 types) | `items/rcd/*.dm` |

**MEDICAL:**

| Equipment | Purpose | Location |
|-----------|---------|----------|
| Defibrillator | Revival | `items/defib.dm` |
| Medkits | Medical supplies storage | `storage/medkit.dm` |
| Implants | 20+ types (freedom, mindshield, explosive, etc.) | `items/implants/` |
| Scanners | Health, chem, gas analyzers | `devices/scanners/` |

**STORAGE:**

| Container | Purpose | Location |
|-----------|---------|----------|
| Backpacks | Personal storage | `storage/backpack.dm` |
| Belts | Equipment belts | `storage/belt.dm` |
| Boxes | Item containers | `storage/boxes/` |
| Toolboxes | Tool storage | `storage/toolboxes/` |

#### VOIDCREW ADDITIONS:

| Item | Type | Location | Purpose |
|------|------|----------|---------|
| **Shuttle Expansion Permit** | Blueprint variant | `voidcrew/objects/items/blueprints.dm` | Expand flyable shuttles, links to helm console |
| **Blade of the Grey-King** | Melee weapon | `voidcrew/objects/items/melee/misc.dm` | Custom sword with drug injection (50% chance to inject random chem on hit) |
| **Letter Opener** | Melee weapon | `voidcrew/objects/items/melee/misc.dm` | Reskinnable combat knife (15 force) |
| **SolGov ID Cards** | ID cards | `voidcrew/objects/items/cards_ids.dm` | Officer, Commander, Elite variants |
| **Robotics Access Card** | Upgrade chip | `voidcrew/objects/items/cards_ids.dm` | Adds ACCESS_ROBOTICS to any ID |
| **Rusting Ammo Printer** | Structure | `voidcrew/objects/items/storage/ammo_printer.dm` | One-use ammo printing for ballistic weapons |
| **Ship Parts Items** | Collectibles | `voidcrew/modules/shuttle/ship_parts/ship_item.dm` | Rarity-based (common/uncommon/rare/epic/legendary) ship part tokens |
| **Gun Vouchers** | Tokens | `voidcrew/modules/vending/security.dm` | Redeem for weapons at marine vendors |
| **Nanite Equipment** | Science gear | `voidcrew/modules/nanites/code/items/` | Scanner, remote, program disks (46+ programs) |
| **Research Notes (Loot)** | Value items | `voidcrew/modules/research/research_notes.dm` | Exotic physics notes (250-10000 value) |
| **Survey Scanner** | Machine | `voidcrew/modules/research/survey_scanner.dm` | Generates research points from planet scanning |
| **Sandblast Sarsaparilla** | Drink | `voidcrew/modules/food_and_drinks/drinks/bottles.dm` | Beverage with bottle crate storage |
| **Survivor Suit/Hood** | Clothing | `voidcrew/modules/mining/equipment/explorer_gear.dm` | Hooded suit with -0.3 slowdown, fire-proof |
| **Cult Bastard Sword** | Weapon | `voidcrew/modules/antagonist/cult/cult_bastard_sword.dm` | 35 force, 50% block, spin2win ability, soul stealing |

#### VOIDCREW STRUCTURES:

| Structure | Type | Location | Purpose |
|-----------|------|----------|---------|
| **Oil/Flaming Barrel** | Decoration | `voidcrew/objects/structures/barrel.dm` | Atmospheric barrels for ruins |
| **Hell Flora** | Decoration | `voidcrew/objects/structures/flora.dm` | Lava planet vegetation (glowing bushes, crimson trees) |
| **Dead Flora** | Decoration | `voidcrew/objects/structures/flora.dm` | Wasteland vegetation (dead grass, barren trees) |
| **Cave Ladder** | Transport | `voidcrew/objects/structures/planet_ladders.dm` | Planet Z-level transitions |
| **Radioactive Hazards** | Hazard | `voidcrew/objects/structures/radioactive.dm` | Nuclear waste barrels, decayed supermatter |
| **Cave Spawner** | Loot source | `voidcrew/objects/structures/spawner.dm` | Searchable caves with weighted loot table |
| **Demonic Portal** | Loot source | `voidcrew/objects/structures/icemoon/cave_entrance.dm` | 24 event types with themed loot/enemies |

#### VOIDCREW CIRCUIT BOARDS:

| Board | Purpose | Location |
|-------|---------|----------|
| Shuttle Heater | Fueled engine heating | `voidcrew/objects/items/circuitboards/` |
| Plasma Thruster | Plasma-based propulsion | `voidcrew/objects/items/circuitboards/` |
| Ion Thruster | Electric propulsion | `voidcrew/objects/items/circuitboards/` |
| Expulsion Thruster | Mass-based propulsion | `voidcrew/objects/items/circuitboards/` |
| Oil Thruster | Liquid fuel propulsion | `voidcrew/objects/items/circuitboards/` |
| Void Thruster | Advanced propulsion (quadratic parts) | `voidcrew/objects/items/circuitboards/` |
| Survey Scanner | Research point generation | `voidcrew/modules/research/survey_scanner.dm` |
| Ship Construction Console | Ship building interface | `voidcrew/modules/shuttle/boards.dm` |
| Shuttle Helm | Ship navigation | `voidcrew/modules/shuttle/boards.dm` |

#### VOIDCREW EDITS (TG Modifications):

| Item | Change | Location |
|------|--------|----------|
| **Storage Belt** | Changed w_class to WEIGHT_CLASS_NORMAL | `voidcrew/objects/items/storage/belt.dm` |
| **Yellow Insulated Gloves** | Removed TRAIT_SIEMENS_PROTECTED clothing trait | `voidcrew/modules/clothing/gloves/insulated.dm` |
| **ID Card** | Disabled alt-click money withdrawal (use bank machine instead) | `voidcrew/edits/id_card.dm` |

#### VOIDCREW CLOTHING:

| Clothing | Type | Location |
|----------|------|----------|
| SolGov Helmet | Head | `voidcrew/modules/clothing/head/helmet.dm` |
| SolGov Officer Cap | Head | `voidcrew/modules/clothing/head/helmet.dm` |
| TerraGov Officer Cap | Head | `voidcrew/modules/clothing/head/helmet.dm` |
| SolGov Envirosuit Helmet | Head (Plasmaman) | `voidcrew/modules/clothing/head/helmet.dm` |
| SolGov Armor Vest | Suit | `voidcrew/modules/clothing/suits/armor.dm` |
| SolGov Inspector Vest | Suit | `voidcrew/modules/clothing/suits/armor.dm` |
| SolGov Waistcoat | Accessory | `voidcrew/modules/clothing/under/accessories.dm` |
| SolGov Fatigues | Under | `voidcrew/modules/clothing/under/solgov.dm` |
| SolGov Elite Jumpsuit | Under | `voidcrew/modules/clothing/under/solgov.dm` |
| SolGov Formal Uniform | Under | `voidcrew/modules/clothing/under/solgov.dm` |
| TerraGov Formal Uniform | Under | `voidcrew/modules/clothing/under/solgov.dm` |
| SolGov Envirosuit | Under (Plasmaman) | `voidcrew/modules/clothing/under/solgov.dm` |

#### VOIDCREW VENDORS:

| Vendor | Contents | Location |
|--------|----------|----------|
| Marine Vendor (Syndicate) | Handcuffs, flash, seclite, ammo (9mm/10mm/45/12g/sniper), C4, frag, energy sword | `voidcrew/modules/vending/security.dm` |
| Marine Vendor (SolGov) | Same + combat hypospray, nuke screwdriver, barrier grenades, blue saber | `voidcrew/modules/vending/security.dm` |

**Voucher Weapons:**
- Syndicate: M-90gl Carbine, Sniper Rifle, C-20r SMG, Bulldog Shotgun
- SolGov: Tactical E-Gun, Inferno Pistol, Cryo Pistol

#### NANITE SYSTEM (Voidcrew Addition):

Complete nanite programming system with 46+ programs:

**Program Categories:**
- **Replication**: Aggressive, Metabolic Synthesis, Viral, Spreading
- **Utility**: Monitoring, Relay, EMP
- **Medical**: Regenerative, Temperature, Purging, Brain Heal, Blood Restoring, Coagulating
- **Combat**: Meltdown, Necrotic, Brain Decay, Pyro, Cryo, Toxic, Suffocating, Heart Stop, Explosive, Shock
- **Control**: Sleepy, Paralyzing, Fake Death, Pacifying, Stun, Glitch
- **Enhancement**: Repairing, Nervous, Hardening, Refractive

**Nanite Items:**
- Nanite Scanner (belt-slot diagnostic tool)
- Nanite Remote Control (wireless signal sender with modes: Off/Local/Targeted/Area/Relay)
- Nanite Communication Remote (text message sender)
- Nanite Program Disks (46+ disk types for each program)
- Nanite Disk Box (storage for 7 blank disks)

#### CAVE SPAWNER LOOT TABLES:

**Standard Cave (wasteland):**
- Weapons: Bow, Nagant Revolver, Boltaction Rifle, Kinetic Crusher, PKA
- Items: Binoculars, Survival Capsules, Stock Parts, Meson Glasses
- Medical: Medipens, Bruise Packs, Ointment, Medkits, Romerol
- Rare: Telecrystals, Diamond Ore, Grey-King Sword, Abductor Wrench

**Beach Barrel:**
- Weapons: Mini Uzi, Gold Deagle, Grenade Launcher, Pirate Energy Sword
- Items: Slimecross variants, Money Bags, Research Notes
- Instruments: Banjo

#### DEMONIC PORTAL EVENTS (24 types):

| Roll | Theme | Key Loot | Enemies |
|------|-------|----------|---------|
| 1 | Clown Hell | Bananium gear, Honk weapons | Clowns, Fleshclowns |
| 2 | Demonic | Gods Eye, His Grace, Nullrod | Migos, Blankbodies |
| 3 | Skeleton | Flight Potion, Claymore, Bow | Skeletons, Templars |
| 4 | Wizard | Spell Books, Staves, Mjollnir | Wizards |
| 5 | Syndicate | MOD suits, Energy Shield, Emag | Syndicate Troops |
| 6 | Blob | Medbeam, Defib, Medical Kits | Blobbernaut, Spores |
| 7 | Ice World | Warp Cube, Ice Boots | Ice Demons, Snow Bears |
| 8 | Swarmers | RCD, Jetpack, Toolbox | (Swarmers commented out) |
| 9 | Blood Drunk | Bloodstone | Blood Drunk Miner (MEGAFAUNA) |
| 10 | Casino | Cash, Gold Coins | Faithless |
| 11-24 | (Various) | Themed loot | Themed enemies |

#### KEY FILES:

TG Items Base:
- code/game/objects/items/ (372 files)
- code/game/objects/items.dm (83KB main item code)
- code/game/objects/structures/ (145 files)
- code/modules/projectiles/guns/ (35 files)
- code/modules/clothing/ (14 directories)

Voidcrew Items:
- voidcrew/objects/items/blueprints.dm (shuttle expansion)
- voidcrew/objects/items/cards_ids.dm (SolGov IDs)
- voidcrew/objects/items/melee/misc.dm (Grey-King Sword, Letter Opener)
- voidcrew/objects/items/storage/ammo_printer.dm (ammo generation)
- voidcrew/objects/items/circuitboards/ (thruster boards)

Voidcrew Structures:
- voidcrew/objects/structures/barrel.dm
- voidcrew/objects/structures/flora.dm (extensive lava/wasteland flora)
- voidcrew/objects/structures/radioactive.dm (hazards)
- voidcrew/objects/structures/spawner.dm (loot caves)
- voidcrew/objects/structures/icemoon/cave_entrance.dm (demonic portals)

Voidcrew Clothing:
- voidcrew/modules/clothing/gloves/insulated.dm
- voidcrew/modules/clothing/head/helmet.dm
- voidcrew/modules/clothing/suits/armor.dm
- voidcrew/modules/clothing/under/solgov.dm

Voidcrew Nanites:
- voidcrew/modules/nanites/code/items/items.dm
- voidcrew/modules/nanites/code/items/nanite_remote.dm
- voidcrew/modules/nanites/code/scanner.dm

Voidcrew Shuttle:
- voidcrew/modules/shuttle/boards.dm
- voidcrew/modules/shuttle/ship_parts/ship_item.dm

#### SUMMARY:

**TG Station provides:**
- Comprehensive item system with 500+ item files
- Full weapon systems (melee, ballistic, energy, magic, grenades)
- Complete tool sets for all departments
- Extensive medical/implant systems
- Modular clothing with slot system
- AI/robot item support

**Voidcrew adds:**
- Ship-focused items (expansion permits, thruster boards, ship parts)
- SolGov faction equipment (uniforms, armor, IDs)
- Unique melee weapons (Grey-King Sword with drug injection)
- Complete nanite programming system (46+ programs)
- Survey scanner for research point generation
- Loot systems (cave spawners, demonic portals with 24 event types)
- Wasteland/lava planet flora and hazards
- Marine vendors with weapon vouchers
- Balance changes (insulated gloves nerf, belt weight change, ID withdrawal disabled)

**Design Philosophy:**
- TG items are largely inherited unchanged
- Voidcrew adds ship-relevant and faction-specific equipment
- Loot systems designed for exploration gameplay
- Nanites add complex science gameplay option

#### KEY FILES:
```
Event Core:
- code/controllers/subsystem/events.dm (SSevents)
- code/modules/events/_event.dm (round_event_control, round_event)
- code/modules/events/_event_admin_setup.dm (admin configuration)
- code/__DEFINES/events.dm (categories, flags)

Event Categories:
- code/modules/events/anomaly/ (10 anomaly types)
- code/modules/events/meteors/ (meteor waves)
- code/modules/events/ghost_role/ (sentience, operative)
- code/modules/events/wizard/ (23 wizard events)
- code/modules/events/shuttle_loan/ (cargo events)
- code/modules/events/space_vines/ (kudzu)
- code/modules/events/immovable_rod/ (rod event)
- code/modules/events/holiday/ (seasonal events)

Dynamic Integration:
- code/controllers/subsystem/dynamic/dynamic.dm
- code/modules/events/dynamic_tweak.dm

Voidcrew Overmap:
- voidcrew/modules/overmap/code/modules/overmap/events.dm
- voidcrew/modules/overmap/code/controllers/subsystem/overmap.dm

Station Traits:
- code/datums/station_traits/_station_trait.dm
- code/datums/station_traits/positive_traits.dm
- code/datums/station_traits/negative_traits.dm
```

---
### DATUMS ANALYSIS
**Agent:** Datums
**Status:** Complete
**Date:** 2025-12-30

#### KEY DATUM SYSTEMS:

##### Components System (ECS-Style)
Location: `code/datums/components/`

**Purpose:** Components attach behaviors to datums via signals, providing composable functionality.

| Component Category | Examples | Count |
|-------------------|----------|-------|
| Combat | acid, caltrop, boomerang, fullauto, parry, tackle | ~20 |
| Movement | chasm, jetpack, shuttle_cling, drift | ~10 |
| Crafting | crafting/, bakeable, grillable | ~5 |
| Audio | jukebox, squeak, speechmod | ~5 |
| Visual | overlay_lighting, bubble_icon_override, space_camo | ~10 |
| AI/Mob | bloodysoles, echolocation, ghost_direct_control | ~15 |
| Items | transforming, twohanded, seclight_attachable | ~20 |
| Misc | uplink, gps, religious_tool, supermatter_crystal | ~50+ |

**Key Architecture:**
- `dupe_mode` controls duplicate handling (HIGHLANDER, ALLOWED, UNIQUE, etc.)
- `can_transfer` allows component migration between parents
- Uses `RegisterWithParent()` / `UnregisterFromParent()` pattern
- Signal-based communication via COMSIG system

##### Elements System (Lightweight Components)
Location: `code/datums/elements/`

**Purpose:** Singletons that attach to many objects for shared lightweight behavior.

| Element Category | Examples | Count |
|-----------------|----------|-------|
| Combat | bane, knockback, venomous, firestacker | ~15 |
| Movement | climbable, ridable, swimming_tile, forced_gravity | ~10 |
| Mob AI | ai_control_examine, ai_retaliate, skittish | ~10 |
| Items | strippable, weapon_description, caseless | ~15 |
| Atmos | atmos_requirements, atmos_sensitive, weather_listener | ~5 |
| Visual | footstep, beauty, art, prosthetic_icon | ~10 |
| Misc | slapcrafting, rust, elevation, turf_transparency | ~50+ |

**Key Architecture:**
- `element_flags` control behavior (ELEMENT_BESPOKE, ELEMENT_DETACH_ON_HOST_DESTROY)
- `argument_hash_start_idx` for bespoke element differentiation
- Managed by SSdcs subsystem

##### Diseases System
Location: `code/datums/diseases/`

| Disease | Severity | Cure | Notes |
|---------|----------|------|-------|
| Cold | Minor | Spaceacillin | Common illness |
| Flu | Minor | Spaceacillin | Common illness |
| Brainrot | Dangerous | Mannitol | Mental degradation |
| Tuberculosis | Biohazard | Spaceacillin | Highly infectious |
| GBS (Genetic) | Biohazard | None | Rapid deterioration |
| Transformation | Varies | Varies | Species changes |
| Advanced Viruses | Varies | Custom | Player-engineered |

**Key Architecture:**
- `disease_flags`: CURABLE, CAN_CARRY, CAN_RESIST
- `spread_flags`: AIRBORNE, CONTACT_FLUIDS, CONTACT_SKIN
- Stage-based progression (1 to max_stages)
- `viable_mobtypes` restricts affected species

##### Quirks System
Location: `code/datums/quirks/`

| Type | Examples | Points |
|------|----------|--------|
| Positive | Alcohol Tolerance, Freerunning, Light Step | Negative cost |
| Neutral | Foreigner, Vegetarian, Heterochromia | 0 |
| Negative | Nearsighted, Prosthetic Limb, Nyctophobia | Positive cost |

**Key Architecture:**
- `value` determines point cost in character creation
- `quirk_flags`: QUIRK_HUMAN_ONLY, QUIRK_CHANGES_APPEARANCE
- `mob_trait` applies/removes mob traits
- `hardcore_value` for hardcore character mode

##### Station Traits System
Location: `code/datums/station_traits/`

| Trait Type | Examples | Notes |
|------------|----------|-------|
| Positive | Random bounty bonuses, Extra equipment | Benefits crew |
| Neutral | Decal colors, Different layout | Cosmetic |
| Negative | Broken equipment, Pest infestations | Challenges |
| Job | Department-specific modifiers | Per-job effects |

**CRITICAL FOR VOIDCREW:**
- Station traits apply to `SSstation` singleton
- Designed for STATIC stations, NOT ships
- `trait_flags`: STATION_TRAIT_MAP_UNRESTRICTED, STATION_TRAIT_PLANETARY
- Ships would need custom `/datum/ship_trait` system

##### Status Effects System
Location: `code/datums/status_effects/`

| Category | Examples | Duration |
|----------|----------|----------|
| Buffs | Speed boost, damage resistance | Timed |
| Debuffs | Stun, confused, incapacitated | Timed |
| Drug Effects | Stimulant, depressant | Variable |
| Gas Effects | Plasma exposure, N2O | While exposed |
| Wound Effects | Bleeding, infected | Until treated |

**Key Architecture:**
- `status_type`: STATUS_EFFECT_UNIQUE, STATUS_EFFECT_MULTIPLE, STATUS_EFFECT_REPLACE
- `processing_speed`: FAST_PROCESS or NORMAL_PROCESS
- `alert_type` for HUD display
- `remove_on_fullheal` for medical integration

##### Wounds System
Location: `code/datums/wounds/`

| Wound Type | Severities | Treatment |
|------------|------------|-----------|
| Bones | Hairline, Compound, Shattered | Bone gel, Surgery |
| Burns | 1st, 2nd, 3rd Degree | Burn treatment, Gauze |
| Pierce | Puncture, Impalement | Pressure, Surgery |
| Slash | Minor, Severe, Critical | Sutures, Cauterization |
| Cranial | Fissure | Surgery |
| Loss | Dismemberment | Prosthetics, Surgery |

**Key Architecture:**
- `severity`: TRIVIAL, MODERATE, SEVERE, CRITICAL, LOSS
- `blood_flow` tracks bleeding rate
- `limp_slowdown` for mobility effects
- `threshold_penalty` for progressive damage
- Scar generation on healing

#### OTHER KEY DATUMS:

| Datum Directory | Purpose | Files |
|----------------|---------|-------|
| `actions/` | Action buttons and cooldowns | 4 files |
| `ai/` | AI behavior trees | Multi-file |
| `ai_laws/` | AI law sets | 4 files |
| `armor/` | Damage resistance | 2 files |
| `brain_damage/` | Mental traumas | 11 files |
| `keybinding/` | Hotkey definitions | Multi-file |
| `martial/` | Combat styles | 10 files |
| `materials/` | Material properties | 6 files |
| `memory/` | Character memories | 4 files |
| `mind/` | Player persistence | 4 files |
| `mutations/` | Genetic mutations | 26 files |
| `shuttles/` | Shuttle templates | 19 files |
| `skills/` | Skill system | 6 files |
| `storage/` | Container logic | 3 files |
| `weather/` | Weather events | Multi-file |
| `wires/` | Hacking puzzles | 32 files |

#### VOIDCREW DATUMS:
Location: `voidcrew/datums/`

| Datum | Purpose | Notes |
|-------|---------|-------|
| `map_zones.dm` | Overmap z-level management | Links to SSovermap |
| `pod_style.dm` | Drop pod visuals | Planetary landing |
| `looping_sounds/sonar.dm` | Sonar audio | Ship navigation |
| `mapgen/PlanetGenerator.dm` | Terrain generation | Perlin noise + biomes |
| `mapgen/biomes/` | Biome definitions | Heat/humidity based |
| `mapgen/Cavegens/` | Cave generation | Cellular automata |
| `mapgen/planets/` | Planet types | Config datums |
| `ruins/` | Ship-appropriate ruins | 8 planet types |
| `votes/transfer_vote.dm` | Crew transfer voting | Calls SSovermap.request_jump() |

**Map Zones System:**
- Manages z-level collections for overmap encounters
- `clear_reservation()` resets turfs to space
- `get_mind_mobs()` finds living players in zone
- Links to SSovermap for encounter management

**Planet Generator:**
- Uses `rustg_cnoise_generate()` for cellular automata terrain
- Heat/humidity values determine biome selection
- Supports overworld + cave layers
- Mountain height threshold controls terrain type distribution

**Transfer Vote:**
- Custom vote type extending TG vote system
- On success: `SSovermap.request_jump()`
- Config toggle: `allow_vote_transfer`

#### NOT IMPLEMENTED/NEEDS WORK:

| System | Current State | Needed for Ships |
|--------|--------------|------------------|
| Ship Traits | Station traits do not apply | Need `/datum/ship_trait` |
| Ship-Specific Quirks | None | Space legs, void walker, etc. |
| Disease Isolation | Station-wide spread | Ship-isolated epidemics |
| Ship Status Effects | Standard effects | Ship-wide radiation, O2 dep |
| Ship Weather | Area-based | Interior ship hazards |
| Ship AI Laws | Standard sets | Captain/crew specific |
| Cross-Ship Combat | None | Boarding trauma/wounds |
| Ship Memories | Character-only | Ship history/achievements |

#### KEY ARCHITECTURAL PATTERNS:

**Signal-Based Communication:**
- `RegisterSignal(target, COMSIG_*, PROC_REF(handler))`
- `UnregisterSignal(target, COMSIG_*)`
- `SEND_SIGNAL(target, COMSIG_*, args...)`

**Component Lifecycle:**
1. `New()` - Sets parent, calls Initialize
2. `Initialize()` - Setup, return COMPONENT_INCOMPATIBLE if invalid
3. `_JoinParent()` - Registers with parent
4. `RegisterWithParent()` - Override for signal registration
5. `Destroy()` - Cleanup and unregistration

**Element Lifecycle:**
1. `Attach(target)` - Called when added to datum
2. Signal registration in Attach
3. `Detach(source)` - Called when removed
4. Singleton persists, only attaches/detaches

#### KEY FILES:
```
Components:
- code/datums/components/_component.dm (base, 16KB)
- code/datums/components/README.md
- code/datums/components/COMPONENT_TEMPLATE.md

Elements:
- code/datums/elements/_element.dm (base, 4KB)
- code/datums/elements/ELEMENT_TEMPLATE.md

Core Datums:
- code/datums/datum.dm (16KB, signals/traits)
- code/datums/diseases/_disease.dm (17KB)
- code/datums/quirks/_quirk.dm (11KB)
- code/datums/station_traits/_station_trait.dm (5KB)
- code/datums/status_effects/_status_effect.dm (10KB)
- code/datums/wounds/_wounds.dm (33KB)

Voidcrew:
- voidcrew/datums/map_zones.dm (4KB)
- voidcrew/datums/mapgen/PlanetGenerator.dm (10KB)
- voidcrew/datums/votes/transfer_vote.dm (1.5KB)
```

---

#### SURGERY SYSTEM:

**Core Architecture** (code/modules/surgery/):
TG surgery is a step-based procedural system where surgeries are defined as /datum/surgery with ordered lists of /datum/surgery_step instances.

| File | Purpose |
|------|---------|
| surgery.dm | Base /datum/surgery definition with targeting, step progression |
| surgery_step.dm | Step execution logic, success/failure handling, pain effects |
| organic_steps.dm | Standard steps: incise, clamp, retract, saw, drill, close |
| mechanic_steps.dm | Robotic surgery steps: open hatch, unwrench, prepare electronics |
| tools.dm | Tool definitions and surgery implements |

**Surgery Mechanics:**
- Surgeries require patient resting (SURGERY_REQUIRE_RESTING flag)
- Zone targeting via possible_locs list (chest, head, groin, limbs)
- Tool success rates defined per step (e.g., scalpel 100%, shard 45%)
- Speed modifiers from tool quality, patient traits (TRAIT_SURGICALLY_ANALYZED)
- Pain system with mood effects and potential screaming
- Step failure causes damage/complications

**Key Surgery Types:**
| Surgery | Purpose | Location |
|---------|---------|----------|
| Organ Manipulation | Insert/extract organs | organ_manipulation.dm |
| Brain Surgery | Fix brain damage, cure traumas | brain_surgery.dm |
| Bone Mending | Repair fractures (hairline, compound) | bone_mending.dm |
| Revival | Bring dead patients back to life | revival.dm |
| Amputation | Remove limbs | amputation.dm |
| Prosthetic Replacement | Attach prosthetic limbs | prosthetic_replacement.dm |
| Burn Dressing | Treat severe burns | burn_dressing.dm |
| Blood Filter | Remove toxins/diseases from blood | blood_filter.dm |
| Coronary Bypass | Treat heart conditions | coronary_bypass.dm |
| Tend Wounds | Heal brute/burn damage surgically | healing.dm |

**Advanced Surgeries** (code/modules/surgery/advanced/):
| Surgery | Purpose | Requires Tech |
|---------|---------|---------------|
| Lobotomy | Remove all traumas (may cause new one) | Yes |
| Brainwashing | Implant loyalty programming | Yes |
| Necrotic Revival | Create zombie tumor | Yes |
| Pacification | Remove violent tendencies | Yes |
| Viral Bonding | Bond virus to host permanently | Yes |
| Wing Reconstruction | Restore flight capability | Yes |

**Bioware Augments** (advanced/bioware/):
Permanent body modifications requiring surgery:
- Cortex Imprint (brain backup)
- Nerve Splicing (pain reduction)
- Nerve Grounding (shock immunity)
- Muscled Veins (blood pressure boost)

#### WOUND SYSTEM:

**Core Architecture** (code/datums/wounds/):
Wounds are applied to bodyparts when damage exceeds thresholds. Three severity tiers:
- MODERATE: Minor complications
- SEVERE: Significant debuffs
- CRITICAL: Disabling/life-threatening

| Wound Type | File | Effects |
|------------|------|---------|
| Bone Fractures | bones.dm | Limb usability, brain trauma (head), pain on attacks |
| Slash/Cut Wounds | slash.dm | Bleeding, blood flow rates, clotting mechanics |
| Pierce Wounds | pierce.dm | Internal bleeding, organ damage |
| Burn Wounds | burns.dm | Damage multiplier, infection risk |
| Cranial Fissure | cranial_fissure.dm | Brain exposure, immediate danger |
| Limb Loss | loss.dm | Complete limb removal tracking |

**Wound Mechanics:**
- blood_flow tracks active bleeding rate
- threshold_penalty makes future wounds easier to inflict
- Gauze/splints reduce wound penalties (limb.current_gauze)
- Cryo treatment heals wounds via cryo_progress
- Wounds generate scars when healed

**Bone Wound Specifics:**
- Hairline fractures (SEVERE): Fixed with bonesetter/bone gel/surgical tape
- Compound fractures (CRITICAL): Require reset + repair surgery
- Head fractures cause brain traumas (periodic trauma cycling)
- Arm fractures affect gun accuracy and melee attacks

**Slash Wound Specifics:**
- Natural clotting rate based on severity
- Bleeding increases when hit again (WOUND_SLASH_DAMAGE_FLOW_COEFF)
- Treatable with sutures, cautery, or laser (with aggro grab)
- Dragging patients causes blood trails

#### DISEASE SYSTEM:

**Core Architecture** (code/datums/diseases/):
Diseases are stage-based infections that progress/regress based on conditions.

| System Element | Purpose |
|----------------|---------|
| _disease.dm | Base disease datum with stage progression |
| _MobProcs.dm | Disease infection/curing mob methods |
| advance/advance.dm | Virology-created custom diseases |
| advance/symptoms/ | Disease symptom components |

**Disease Mechanics:**
- Spread types: Airborne, contact fluids, contact skin
- Stage progression (1 to max_stages) with severity scaling
- Cure system: Reagents cure diseases if CURABLE flag set
- Natural recovery: Sleeping, good mood, nutrition aid recovery
- Immunity: Cured diseases grant resistance
- Required organs: Some diseases need specific organs to function

**Disease Severity Levels:**
| Severity | Recovery Difficulty | Examples |
|----------|--------------------|---------|
| POSITIVE | Wont cure naturally if well-fed | Beneficial viruses |
| NONTHREAT | Easy | Common cold |
| MINOR | Easy-Medium | Flu |
| MEDIUM | Medium | Brain rot |
| DANGEROUS | Hard | Tuberculosis |
| HARMFUL | Very Hard | Spanish flu |
| BIOHAZARD | Extremely Hard | GBS |
| UNCURABLE | Cannot cure | Chronic conditions |

**Disease Types:**
| Disease | Severity | Effects |
|---------|----------|---------|
| Cold | MINOR | Sneezing, minor symptoms |
| Flu | MINOR | Fever, weakness |
| Brain Rot | DANGEROUS | Intelligence loss, brain damage |
| Tuberculosis | DANGEROUS | Respiratory distress |
| GBS (Fake/Real) | BIOHAZARD | Rapid death (real) |
| Wizarditis | DANGEROUS | Random spell casting |
| Chronic Illness | UNCURABLE | Permanent debuffs |

**Advanced Virology** (advance/):
- Custom symptom combination system
- Symptoms have stat modifiers (transmission, stealth, resistance, etc.)
- Preset symptom combinations for specific effects
- Symptom types: cough, sneeze, vision, genetics, fire, heal, etc.

#### MEDICAL MACHINERY:

**Cryo Cell** (code/modules/atmospherics/machinery/components/unary_devices/cryo.dm):
- Heals patients using cryoxadone/similar reagents
- Requires cold gas atmosphere to function
- Efficiency scales with machine parts
- Auto-eject when healing complete
- Can treat wounds via cryo_progress accumulation

**Defibrillator** (code/game/objects/items/defib.dm):
- Revives recently deceased patients
- Requires cell power, wielded paddles
- Combat mode toggle (safety on/off)
- Use in revival surgery for surgical revival

**Other Medical Equipment:**
| Equipment | Purpose | Location |
|-----------|---------|----------|
| Health Analyzer | Diagnose patient conditions | code/game/objects/items/ |
| Body Scanner | Detailed body analysis | code/game/machinery/ |
| Sleeper | Basic chemical injection | code/game/machinery/sleepers.dm |
| Operating Table | Surgery speed bonus, computer link | code/game/objects/structures/ |
| Operating Computer | Advanced surgery unlock, patient monitoring | code/game/machinery/computer/ |

#### BRAIN DAMAGE/TRAUMA:

**Brain Surgery** (brain_surgery.dm):
- Fixes 50 brain damage per success
- Cures traumas up to TRAUMA_RESILIENCE_SURGERY level
- Removes brainwashing antagonist datum
- Failure causes +60 brain damage and SEVERE trauma

**Lobotomy** (advanced/lobotomy.dm):
- Cures ALL traumas (including RESILIENCE_LOBOTOMY level)
- 75% chance to cause new trauma (MILD/SEVERE/SPECIAL)
- New traumas have TRAUMA_RESILIENCE_MAGIC (uncurable)

**Brain Trauma Types:**
| Resilience Level | Curable By |
|------------------|-----------|
| BASIC | Rest/time |
| SURGERY | Brain surgery |
| LOBOTOMY | Lobotomy only |
| MAGIC | Cannot be cured |
| WOUND | Healing wound cures it |

#### REVIVAL/CLONING:

**Revival Surgery** (revival.dm):
- Works on dead patients with intact brain
- Uses defibrillator/shock paddles/batons/lasers
- Reduces 50 oxy damage, unfreezes heart
- Calls revive() on success
- Causes 50 brain damage on revival (mad science penalty)
- Carbon-specific version for brain-havers

**Revival Requirements:**
- Cannot revive: suicides, husks, DEFIB_BLACKLISTED
- Needs intact brain organ
- Body must be able to sustain life

**Cloning Notes:**
- No dedicated cloning pod system found in surgery
- Cloning referenced in chemistry/xenobiology contexts
- Synthflesh heals some wound types

#### CHEMISTRY INTERACTIONS:

**Key Medical Chemicals:**
| Chemical | Effect | Wound Interaction |
|----------|--------|-------------------|
| Cryoxadone | Heals in cold | Increases wound cryo_progress |
| Pyroxadone | Heals when on fire | Similar to cryo |
| Synthflesh | Heals brute/burn | Calls on_synthflesh on wounds |
| Determination | Produced by wounds | Temporary combat boost |
| Spaceacillin | Slows disease | TRAIT_VIRUS_RESISTANCE |
| Bone Gel | Bone repair | Surgery implement (100%) |

**Surgery Tool Substitutes:**
| Tool | Standard Success | Substitutes |
|------|------------------|-------------|
| Scalpel | 100% | Energy sword (75%), knife (65%), shard (45%) |
| Hemostat | 100% | Wirecutter (60%), package wrap (35%) |
| Retractor | 100% | Screwdriver (45%), wirecutter (35%) |
| Cautery | 100% | Laser gun (90%), welder (70%) |
| Saw | 100% | Serrated shovel (75%), arm blade (75%) |

#### VOIDCREW STATUS:

**Voidcrew Modifications** (voidcrew/modules/surgery/):

Only one file modified: experimental_dissection.dm
- Adds tiered dissection surgeries: Basic, Advanced, Superior, Elite
- Each tier requires previous tier researched
- Research point rewards scale by target species:
  - Monkeys: 1/5 cost (easiest)
  - Abductors: 4x cost (highest)
  - Aliens: 5-10x cost
  - Golems/Zombies: 3x cost
  - Jellies/Podpeople: 2x cost
- Faster dissection times at higher tiers (8s -> 4s -> 1s)

**Inherited TG Systems:**
| System | Status |
|--------|--------|
| All Surgery Types | INHERITED (unmodified) |
| Wound System | INHERITED (unmodified) |
| Disease System | INHERITED (unmodified) |
| Cryo Healing | INHERITED (unmodified) |
| Defibrillator | INHERITED (unmodified) |
| Brain Trauma | INHERITED (unmodified) |
| Revival Surgery | INHERITED (unmodified) |
| Organ Transplants | INHERITED (unmodified) |

#### NOT IMPLEMENTED / MISSING:

| Feature | Notes |
|---------|-------|
| Custom Ship Medical Bay | No Voidcrew-specific medical facilities |
| Space Exposure Injuries | Standard TG, no ship-specific handling |
| EVA Medical Treatment | No modifications for zero-G/spacesuit treatment |
| Cloning Pod | Not present (TG removed traditional cloning) |
| Medical Drone | No automated medical assistant |
| Voidcrew-Specific Diseases | No space-travel diseases |
| Radiation Sickness Expansion | Standard TG system only |
| Prosthetic Ship Parts | No integration with ship systems |
| Remote Surgery | No telemedicine across ships |

#### KEY FILES:

Surgery Core:
- code/modules/surgery/surgery.dm (datum definition)
- code/modules/surgery/surgery_step.dm (step mechanics)
- code/modules/surgery/organic_steps.dm (incise, clamp, etc.)
- code/modules/surgery/tools.dm (implements)

Wounds:
- code/datums/wounds/_wounds.dm (base datum)
- code/datums/wounds/bones.dm (fractures)
- code/datums/wounds/slash.dm (cuts/bleeding)
- code/datums/wounds/burns.dm (thermal)

Diseases:
- code/datums/diseases/_disease.dm (base datum)
- code/datums/diseases/advance/advance.dm (virology)
- code/datums/diseases/advance/symptoms/ (symptom library)

Medical Equipment:
- code/modules/atmospherics/machinery/components/unary_devices/cryo.dm
- code/game/objects/items/defib.dm
- code/game/machinery/sleepers.dm

Brain/Organs:
- code/modules/surgery/brain_surgery.dm
- code/modules/surgery/organs/_organ.dm
- code/modules/surgery/advanced/lobotomy.dm

Voidcrew:
- voidcrew/modules/surgery/experimental_dissection.dm (only modification)

---
