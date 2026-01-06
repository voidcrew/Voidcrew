# NPC Ships - Design Document

## Overview

This document outlines planned features and systems for NPC ships in Voidcrew.

---

## Ship Type Abstraction ✅ IMPLEMENTED

### Goal
Support different ship types with customizable properties.

### Implemented Ship Types
- **Pirates** (`/obj/structure/overmap/ship/npc/pirate`) - Hostile, attack on sight, spawns in RED zone
- **Traders** (`/obj/structure/overmap/ship/npc/trader`) - Non-hostile, spawns in GREEN/YELLOW zones

### Planned Ship Types
- **Nanotrasen Security** - Spawned in response to player crimes, hunt bounties
- **Syndicate** - Enemy of NT, hostile to NT ships and players
- **Raid Boss Fleets** - Multi-ship encounters with escalating difficulty

### Per-Ship Properties (implemented)
```dm
/obj/structure/overmap/ship/npc
    var/hostile = TRUE                    // Attack on sight?
    var/territory_range = 2               // Aggro range in tiles
    var/ship_color = null                 // Faction color tint
    var/speed_limit = 0.5                 // Max speed (tiles/tick)
    var/thrust_power = 0.3                // Acceleration per burn
    var/lock_time = 5 SECONDS             // Weapon lock time
    var/laser_cooldown_time = 5 SECONDS
    var/missile_cooldown_time = 10 SECONDS
    var/crew_min = 3
    var/crew_max = 6
    var/list/crew_types = list()          // Mob types to spawn
```

### Spawn Zones (in spawner_subsystem.dm)
Spawn zones are configured in `SSnpc_ships.get_spawn_zones_for_type()`:
- Pirates: RED zone only
- Traders: GREEN and YELLOW zones

---

## Faction Warfare

### Goal
NPC ships belong to factions that have relationships with each other. Ships of hostile factions will fight each other automatically.

### Planned Factions
- **Pirates** (`FACTION_PIRATE`) - Hostile to everyone except other pirates
- **Nanotrasen** (`FACTION_NANOTRASEN`) - Hostile to pirates and syndicate
- **Syndicate** (`FACTION_SYNDICATE`) - Hostile to nanotrasen
- **Traders** (neutral) - Not hostile to anyone, but will defend if attacked
- **Players** - Faction based on ship allegiance or bounty status

### Faction Relationships
```
             Pirates    NT    Syndicate    Traders    Players
Pirates        -       ⚔️       ⚔️          ⚔️         ⚔️
Nanotrasen    ⚔️        -       ⚔️          ✓         ⚔️*
Syndicate     ⚔️       ⚔️        -          ⚔️         ⚔️
Traders       ✓        ✓        ✓           -          ✓

⚔️ = Hostile on sight
✓ = Neutral/Friendly
* = NT hostile to players with bounty
```

### Implementation Notes
- Ships already have `faction` list var (from parent)
- Need `faction_enemies` list to define who to attack
- Update `scan_threats` to check faction relationships
- NPC vs NPC combat uses same systems as NPC vs player
- Victory conditions: one faction destroys/disables the other

### Use Cases
- **Pirate vs NT patrol**: Players stumble on a battle in progress
- **Syndicate raid on NT convoy**: Escort mission opportunity
- **Three-way battle**: Pirates attack while NT and Syndicate are fighting
- **Player intervention**: Help one side for reputation/rewards

### Per-Ship Faction Config
```dm
/obj/structure/overmap/ship/npc/pirate
    faction = list(FACTION_PIRATE)
    var/list/enemy_factions = list(FACTION_NANOTRASEN, FACTION_SYNDICATE)

/obj/structure/overmap/ship/npc/nanotrasen
    faction = list(FACTION_NANOTRASEN)
    var/list/enemy_factions = list(FACTION_PIRATE, FACTION_SYNDICATE)

/obj/structure/overmap/ship/npc/syndicate
    faction = list(FACTION_SYNDICATE)
    var/list/enemy_factions = list(FACTION_NANOTRASEN)
```

---

## NPC Ship Captains & Ship Claiming

### Concept
Each NPC ship has a captain mob that carries a **ship key**. Killing the captain and taking the key allows players to claim the ship.

### Implementation Notes
- Captain is a special mob type spawned on the bridge
- Ship key is a physical item that grants ownership
- Claiming a ship could:
  - Transfer shuttle ownership to the player
  - Allow access to helm/controls
  - Disable AI controller
  - Mark ship as "captured" (no longer NPC)

### Questions
- Can multiple players claim the same ship?
- What happens to existing crew when ship is claimed?
- Can claimed ships be added to a "fleet"?

---

## Win Conditions for NPC Combat

### Goal
Validate that players have clear win conditions when fighting NPC ships.

### Win Conditions
1. **Disable** - Destroy all weapons and engines (ship is helpless)
2. **Kill via Weapons** - Reduce hull to 0% / destroy ship
3. **Board and Clear** - Interdict, dock, kill all crew aboard
4. **Force Crash** - Make them crash into an obstacle (sun, asteroid field)

### Implementation Notes
- Need to track weapon/engine destruction state
- Need to detect when all crew are dead
- Crash detection already exists (ship.state changes)
- Could award different rewards based on win condition (boarding = more loot)

---

## Trader Ships & Economy

### Concept
Non-hostile merchant ships that players can:
- Request to dock with for trading
- Attack for piracy (with consequences)

### Trading System
- Hail trader ship to request docking
- Trader accepts/denies based on reputation
- Docking allows access to trade interface
- Traders sell supplies, equipment, rare items

### Piracy & Bounty System
- Attacking traders flags player as hostile
- Generates a **bounty** value that increases with crimes
- Higher bounty = more NT security ships respond
- Bounty could decay over time or be paid off

### Trader Behavior
- Basic weapons for self-defense
- Attempt to flee when attacked
- Send distress signal that summons NT security
- Won't attack unless provoked

---

## Nanotrasen Security Response

### Concept
Law enforcement ships that hunt players with bounties.

### Spawn Rules
- Triggered by: attacking traders, high bounty, distress signals
- Spawn in GREEN zone and navigate to target
- Number and tier based on bounty level

### Bounty Tiers
| Bounty | Response |
|--------|----------|
| Low | 1 light security vessel |
| Medium | 2 security vessels |
| High | 3 vessels + 1 heavy |
| Extreme | Full security fleet |

### Behavior
- Lock onto specific player ship (not zone-based)
- Chase across zone boundaries (unlike pirates)
- Can interdict fleeing criminals
- Announce warnings before engaging

---

## Ship Fleets / Flocks

### Concept
Multiple ships that travel and fight together as a unit.

### Use Cases
- NT security response squads
- Pirate raiding parties
- Trade convoys (with escort)
- Raid boss encounters

### Implementation Notes
- Fleet datum that manages member ships
- Shared target tracking
- Formation movement (leader + followers)
- Coordinated combat (focus fire, flanking)

### Fleet Behaviors
- Follow fleet leader
- Engage same targets
- Regroup when separated
- Can lock onto specific coordinates (not just zones)

---

## Raid Boss Encounters

### Concept
Multi-stage fleet battles with escalating difficulty, spanning multiple Z-levels.

### Structure
```
Fleet Encounter
├── Stage 1: Escort ships (Z-level 1)
│   └── 2-3 light ships, basic loot
├── Stage 2: Defense ships (Z-level 2)
│   └── 2 medium ships, better loot
└── Stage 3: Flagship (Z-level 3)
    └── 1 heavy ship + captain, rare loot
```

### Progression
1. Engage fleet on overmap
2. Defeat/board Stage 1 ships
3. Dock and clear Z-level 1
4. Access opens to Z-level 2
5. Repeat until flagship defeated

### Mission Integration
- Raid encounters as mission objectives
- Mission tracker shows stage progress
- Bonus rewards for full clear
- Time limits or reinforcement waves

### Loot System
- Each stage has loot tables
- Flagship has rare/unique drops
- Bonus loot for boarding vs destroying
- Captain drops ship key for flagship

---

## Pirate Boarding Mechanics

### Concept
Pirates with interdictors can force-dock and invade player ships.

### Trigger Conditions
- Pirate has interdictor
- Player ship is interdicted
- Pirate ship is adjacent

### Boarding Process
1. Pirate ship force-docks to player ship
2. Airlocks breach or connect
3. Pirate crew AI activates boarding behavior
4. Pirates attempt to kill crew, steal loot, destroy ship

### Pirate Boarding AI
- Navigate to player ship interior
- Attack any non-pirate mobs
- Target critical systems (engines, shields, helm)
- Retreat to ship if taking heavy losses
- Undock and flee if ship is disabled

### Player Counterplay
- Repel boarders with crew combat
- Seal airlocks to slow invasion
- Destroy pirate ship while docked (risky)
- Surrender mechanic?

---

## Mission Integration

### Mission Types
- **Patrol** - Clear pirates from a zone
- **Escort** - Protect trader convoy
- **Bounty Hunt** - Hunt specific NPC ship
- **Raid** - Assault fleet encounter
- **Trade Run** - Deliver goods between traders
- **Rescue** - Save disabled ship / stranded crew

### Reward Types
- Credits
- Equipment/weapons
- Ship upgrades
- Reputation (affects trader prices, NT response)
- Rare items from raid bosses

---

## Priority / Implementation Order

### Phase 1: Foundation ✅ COMPLETE
- [x] Ship type abstraction (per-ship vars)
- [x] Spawn zone configuration (in spawner)
- [x] Faction colors
- [ ] Win condition detection

### Phase 1.5: Faction Warfare
- [ ] Add `enemy_factions` list to ship types
- [ ] Update `scan_threats` to target enemy faction ships
- [ ] NPC vs NPC combat support
- [ ] Add Nanotrasen and Syndicate ship types

### Phase 2: Economy
- [ ] Trader ships (basic)
- [ ] Docking/trading interface
- [ ] Bounty system foundation

### Phase 3: Security Response
- [ ] NT security ships
- [ ] Cross-zone targeting
- [ ] Bounty-based spawning

### Phase 4: Fleets
- [ ] Fleet datum
- [ ] Formation movement
- [ ] Coordinated combat

### Phase 5: Boarding
- [ ] Pirate boarding AI
- [ ] Force dock mechanics
- [ ] Interior combat improvements

### Phase 6: Raids
- [ ] Multi-Z encounters
- [ ] Stage progression
- [ ] Mission integration
- [ ] Loot tables

### Phase 7: Polish
- [ ] Ship captains & claiming
- [ ] Full mission system
- [ ] Balance pass

---

## Open Questions

1. How do fleets handle member ships being destroyed?
2. Should bounties persist across rounds?
3. How to balance boarding vs ranged combat rewards?
4. Can players form their own fleets with claimed ships?
5. How do raids spawn - fixed locations or dynamic?
6. What prevents players from cheesing raids (dock, loot, undock, repeat)?

---

## Technical Notes

### Files to Modify
- `npc_ship.dm` - Ship type vars
- `npc_ship_controller.dm` - AI abstraction
- `_defines.dm` - Move to per-ship vars
- New: `fleet_datum.dm` - Fleet management
- New: `trader_ship.dm` - Trader behavior
- New: `security_ship.dm` - NT security
- New: `boarding_ai.dm` - Boarding behavior
- New: `bounty_system.dm` - Bounty tracking

### Subsystems Needed
- Bounty tracking subsystem
- Fleet management subsystem
- Mission subsystem integration

