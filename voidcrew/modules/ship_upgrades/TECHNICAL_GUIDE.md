# Modular ship technical guide

This is the implementation reference for modular ships: registration, loader
behavior, map alignment, source ownership, crew and costs. For building and
editing maps in [Voidcrew StrongDMM](https://github.com/voidcrew/StrongDMM),
follow the [Ship Workshop mapper guide](MAPPER_GUIDE.md).

The manual authoring steps below describe the game's DM and DMM contract.
Workshop creation actions handle many of these steps. Before hand-editing a
Workshop project's generated definitions, read
[source ownership](#workshop-files-and-source-ownership).

| What you want to do | Start here |
| --- | --- |
| Understand how selections become maps | [Runtime assembly](#runtime-assembly) |
| Review files produced by the editor | [Workshop files and source ownership](#workshop-files-and-source-ownership) |
| Register or repair a room manually | [Edit or add a module](#edit-or-add-a-module) |
| Register a theme or hull manually | [Add a theme](#add-a-theme) and [add a modular hull](#add-a-modular-hull) |
| Define room areas and docking ownership | [Areas and ship ownership](#areas-and-ship-ownership) |
| Fix an empty slot, misplaced room or missing preview | [Troubleshooting](#troubleshooting) |

## Runtime assembly

A **hull template** identifies the ship class. A **theme** chooses its hull map
and base crew. An **upgrade slot** is a named position on that hull. A **module**
is a room map that can load into one slot, and can add crew jobs of its own.

For example, the Delta's `delta_cafe` slot can hold its default diner or a
greenhouse. The selected theme chooses the hull and, if present, the matching
appearance of the room. The greenhouse also adds a Botanist job.

The loader:

1. Loads the hull selected by the theme's `template_suffix`, or the template's
   `suffix` when there is no theme.
2. Finds each `/obj/modular_map_root/ship_upgrade` marker in that hull.
3. Uses the module selected for the marker's `key`, or the slot's default module.
4. Looks for the module's themed file, then falls back to its base `map_file`.
5. Aligns the module's `/obj/modular_map_connector` with the hull marker and
   loads the room there.

These are additions made while spawning the ship. A module's name does not
determine its location or dimensions; the markers and map contents do.

## Files you will work with

Paths below are relative to the repository root.

| File or directory | Purpose |
| --- | --- |
| [`voidcrew/mapping/shuttles/`](../../mapping/shuttles/) | Hull template, mobile docking port and ship areas. Some ships are in subdirectories. |
| [`voidcrew/modules/ship_upgrades/ships/`](ships/) | Module and theme definitions. Read the ship's header comments for slot geometry and infrastructure ownership. |
| [`_maps/voidcrew/ships/`](../../../_maps/voidcrew/ships/) | Hull maps named `ship_<suffix>.dmm`. |
| [`_maps/voidcrew/ship_modules/`](../../../_maps/voidcrew/ship_modules/) | Room maps, grouped by ship. `map_file` is relative to this directory. |
| [`tgstation.dme`](../../../tgstation.dme) | Includes new DM source files. A room DMM is loaded through its definition, not a new DME include. |
| [`voidcrew/modules/ship_upgrades/previews/`](previews/) | Generated hull and module PNGs plus `manifest.json`. |

The ship loader only reads `directory` from
[`ship_upgrades.toml`](ship_upgrades.toml). **Do not add room registrations to
the TOML.** Its old `[rooms.*]` entries are not used by ship upgrade markers.
Register modules and themes with DM datums. Hand-written ship definitions
normally live in `ships/`; Workshop output is described below.

## Workshop files and source ownership

Ship Workshop reads the loaded DME's hull, theme and module definitions and
composes their maps into an editable view. Each part retains its source DMM and
placement offset. Selecting a part directs edits into that map; the assembled
view is not saved as a flattened replacement hull.

Paths below use the ship's file identifier. These directories are created when
the corresponding authoring feature is first saved.

| Output | Purpose |
| --- | --- |
| `voidcrew/mapping/ship_projects/<id>.ship.json` | Settings and structure for a ship created through the Workshop. |
| `voidcrew/mapping/shuttles/<id>.dm` | Generated hull template, mobile docking port and root ship area. |
| `voidcrew/modules/ship_upgrades/ships/<id>.dm` | Generated themes and room options for a Workshop-created ship. |
| `voidcrew/mapping/ship_projects/<id>.areas.json` and `voidcrew/mapping/ship_areas/<id>.dm` | Area authoring metadata and the generated area types. |
| `voidcrew/mapping/ship_projects/<id>.crew.json` and `voidcrew/mapping/ship_crew/<id>.dm` | Crew authoring metadata and custom outfit definitions. Roster lists also live on their hull, theme or module datums. |
| `voidcrew/modules/ship_upgrades/workshop/<id>.dm` | Additional room options created on an existing hand-written ship. |
| `_maps/voidcrew/ships/ship_<suffix>.dmm` and `_maps/voidcrew/ship_modules/<id>/...` | Hull and room maps. Rooms added to hand-written ships use a `workshop/` subdirectory under the ship's module directory. |
| `tgstation.dme` | Includes the new DM files. |

Commit the relevant metadata, definitions, includes and maps together. The game
uses the DM/DMM files; the editor uses the JSON files to resume authoring.

On existing hand-written ships, room creation updates the selected theme's
effective slot list, or the hull's list for a themeless ship, and adds separate
module definitions. Crew editing updates the relevant roster lists. Existing
custom definitions are preserved around those changes.

On Workshop-created ships, changing project settings can regenerate the hull
and module definitions. **Arbitrary DM changes are not imported back into the
project JSON.** The editor checks generated sources against its expected output
and stops a save when those sources contain unrepresented edits. It also stops
when a file changes externally during an editing session. Preserve both versions
and reconcile the source and project state before resuming; simply reopening
does not resolve a generated-source mismatch.

Use the Workshop for the fields it exposes. Hand-written theme/module prices,
specialized template behavior and other unsupported fields need maintainer
integration with this ownership model. Do not add a second definition for the
same module ID to work around it.

### Scope of creation actions

- **Make an upgrade room** creates a slot and a default option in the selected
  variant. It leaves turfs and areas in the hull, along with docking ports,
  doors, atmos machinery, cables, power machinery, lights, alarms, cryopods and
  mapping markers. Other selected objects move to the new module. Inspect the
  result against the ship's infrastructure requirements.
- **Create another room option** creates an option for the selected variant.
  Copying includes its jobs and gives copied custom outfits independent authoring
  data. Starting empty retains alignment markers but begins with noop tiles
  and no added crew.
- **Copy ship as a new variant** is available for Workshop-created ships. It
  copies the current hull and every available room option's map, extends those
  options' theme availability and copies an explicit variant roster if present.
  Room job lists remain attached to the shared module datums.
- Existing hand-written ships support new slots and options, area creation,
  docking setup and crew editing. Adding a theme to them currently requires
  the [manual theme workflow](#add-a-theme).

## Edit or add a module

### 1. Read the slot notes before opening the room

Find the ship's file under `ships/`, then read the comments for your slot.
They describe its dimensions, connector position, reserved hull tiles and
equipment every replacement must supply. Inspect the hull alongside the room.

For example:

- [Delta](ships/delta.dm) keeps slot power, atmos and alarms in the hull.
  Its modules must preserve those systems and their approaches. A self-contained
  machine loop, such as the cryo equipment, is an exception documented there.
- [Scarab](ships/scarab.dm) has slots that supply their area's APC, and its
  engineering modules must supply the power plant and air supply. Copying
  Delta's infrastructure rule onto a Scarab would leave it without vital systems.

Changing a module's geometry affects every theme that can select it. Keep the
existing dimensions and connector position for ordinary room edits.

### 2. Find the map that actually loads

For a new option, copy an existing room for the same slot into that ship's
module directory under a new filename, then edit the copy. Create themed
copies as needed. For an existing option, first check which file the selected
theme will use.

Given this definition:

```dm
map_file = "delta/delta_cafe_greenhouse.dmm"
```

The `syndicate` theme first tries
`_maps/voidcrew/ship_modules/delta/delta_cafe_greenhouse_syndicate.dmm`.
If that file is absent, it tries
`_maps/voidcrew/ship_modules/delta/delta_cafe_greenhouse.dmm`.

**Editing the base file does not change an existing themed file.** Update each
affected variant when making a layout or equipment change shared across themes.

Scarab currently has only themed module files, such as
`scarab/scarab_med_basic_medical.dmm`; the base filename in `map_file` is a
lookup name with no base DMM on disk. Every allowed Scarab theme must have a
file for every module it can use. If neither filename exists, the loader removes
the marker and leaves the slot unfilled.

### 3. Preserve alignment and hull tiles

Each room needs **exactly one** `/obj/modular_map_connector`. It is an alignment
anchor, not necessarily a doorway or the room's bottom-left corner. There is no
automatic rotation based on the marker's facing; map the room in hull orientation.

Coordinates start at `(1, 1)` in the bottom-left, with `x` increasing east and
`y` increasing north. A module tile lands at:

```text
hull tile = hull marker + module tile - module connector
```

For the Scarab medical slot, the hull marker is `(23, 7)` and the connector is
at module coordinate `(2, 3)`. Module tile `(1, 1)` lands at `(22, 5)`, so the
3 by 4 room occupies hull coordinates `x=22..24`, `y=5..8`.

The two `template_noop` types do different jobs:

| In the module | Effect when loaded |
| --- | --- |
| `/area/template_noop` | Keeps the hull's area, including its power and alarm grouping. Use this throughout ordinary ship modules. |
| `/turf/template_noop` | Keeps the hull's turf at that position. Use it for reserved tiles and padding outside the room. |
| A normal floor or wall turf | Replaces the hull turf at that position. A blank-looking floor tile is still a replacement. |

A tile that must leave the hull completely alone should contain only:

```dm
"a" = (
/turf/template_noop,
/area/template_noop)
```

This is a tile-definition fragment, not a complete DMM. Objects placed on a
noop tile **still load**. Modules also add objects alongside existing hull
objects; painting a new floor does not erase a hull console or locker. Avoid
duplicate machinery and objects on reserved tiles.

Keep the entire module footprint inside the hull's intended slot, with noop
padding wherever its rectangle crosses permanent walls, windows or other rooms.
The loader does not infer the room boundary for you.

### 4. Register a new room option

Editing an existing module's DMM needs no new datum. For a new option, copy a
sibling module definition in the ship's `ships/` file, then set:

- A new `id`, unique within that ship, and a new DM subtype path.
- A short `name` and a `desc` explaining its equipment and any added jobs.
- The existing slot's exact key in `slot`.
- The new relative filename in `map_file`.
- The themes that can use it, inherited or explicitly set in `for_theme`.
- An appropriate `part_cost` and, if needed, `job_slots_add`.

Keep existing IDs when updating existing content: player unlocks refer to them.

Here is the existing Delta greenhouse definition in shortened form. It inherits
`for_ship` and `for_theme` from `/datum/ship_upgrade_module/delta`; use a new
subtype, ID and filename when creating your own option.

```dm
/datum/ship_upgrade_module/delta/cafe_greenhouse
	id = "delta_cafe_greenhouse"
	name = "Greenhouse Cafe"
	desc = "Hydroponics equipment and a biogenerator. Adds a Botanist."
	slot = "delta_cafe"
	map_file = "delta/delta_cafe_greenhouse.dmm"
	part_cost = list(PART_CLASS_TRADE = 6)
	job_slots_add = list(
		list(
			name = "Botanist",
			outfit = /datum/outfit/job/botanist,
			category = JOB_CAT_SERVICE,
			slots = 1,
		),
	)
```

`job_slots_add` appends jobs to the theme's crew at launch, including jobs from
default modules. It does not replace the base crew. Use a job outfit with a
valid `jobtype`, and provide the workspace and equipment for each added role.

For themed ships, `for_theme` must match the theme's **ID**, not its display
name. It accepts a string or a list:

```dm
for_theme = "salvage"
// Or, for an option shared across all current Delta themes:
for_theme = list("salvage", "syndicate", "cult", "lightship")
```

For a ship without selectable themes, leave `for_theme` unset. An unset value
does not make a module available to every theme on a themed ship.

Keep **one default module per ship and slot**, marked `is_default = TRUE`.
The fallback lookup is by ship and slot, without a theme filter. Make that
default usable for every theme containing the slot, with all necessary map
variants. Do not mark each theme's separate option as another default.

Finish with [previews](#regenerate-ship-previews) and [validation](#validate-and-submit).

## Add a theme

A theme is a `/datum/ship_theme` for an existing hull class. Copy a theme from
that ship's `ships/` file and change the following fields:

| Field | What to set |
| --- | --- |
| `for_ship` | The base hull template type; usually inherited from the ship's theme parent. |
| `id` | A unique theme ID within the ship. This also selects the module filename suffix. |
| `name`, `desc` | The variant's display name and a brief description. |
| `template_suffix` | Hull filename without `ship_` or `.dmm`. For example, `scarab_b` loads `ship_scarab_b.dmm`. |
| `job_slots` | The theme's base crew. Use the existing list format with `name`, `outfit`, `category` and `slots`; mark the captain role `officer = TRUE`. |
| `upgrade_slot_ids` | Only set this to override the hull's slot list. A nonempty list replaces that list; omitting it uses the hull's slots. |
| `part_cost` | Cost to unlock this theme. See [costs](#costs-and-starting-equipment). |
| `is_default` | Keep exactly one default theme for the ship. Leave this false for an additional optional theme. |

Then:

1. Copy the hull DMM to the filename matching `template_suffix`. Use appropriate
   ship areas and a mobile docking port whose `area_type` covers them. Lettered
   ports such as `/a` and `/b` are an existing naming convention, not a loader
   requirement.
2. Keep the same slot geometry unless you are also providing compatible rooms
   for the new geometry. Match every marker `key` to the theme's effective slot
   list and module `slot` values.
3. Add the ID to the hull's `available_themes`, and to each intended module's
   `for_theme` list, including the defaults. The registry comes from theme datums;
   `available_themes` is also used by spawning and crew setup, so keep both aligned.
4. Add `<module_base>_<theme_id>.dmm` reskins where needed. Check every allowed
   module has either that file or a usable base fallback. For Scarab, all allowed
   modules need themed files because it has no base fallback maps.
5. Inspect the assembled ship room by room. Match floors across hull/module seams,
   preserve wall mounting faces and reserve tiles, and make sure the new crew's
   equipment and access work.

The Scarab's historical IDs are easy to misread: `medical` is Hospital,
`syndicate` is Reinforced, and `mining` is Security. Copy the IDs from
[its definitions](ships/scarab.dm), not from the visible theme names.

## Add a modular hull

Use a current ship as a starting point: [Delta's hull definition](../../mapping/shuttles/delta.dm)
and [its themes and modules](ships/delta.dm) show how the two source files work
together. Read their geometry notes before adapting the maps.

1. **Create the hull definition** under `voidcrew/mapping/shuttles/`. Set `name`,
   `short_name`, `catalog_desc`, and a `suffix` matching the hull DMM you will
   create. Set `has_upgrade_slots = TRUE`, list the slot keys in `upgrade_slot_ids`,
   and list selectable theme IDs in `available_themes`. Hull unlock cost belongs
   in `part_requirements`.
2. **Define the mobile docking port and areas.** Map the matching
   `/obj/docking_port/mobile/voidcrew/...` subtype and assign the hull to areas
   under its `area_type`. Preserve the donor ship's port geometry only if the
   new hull has the same shape and orientation. Test docking after changing it.
3. **Build the hull** in `_maps/voidcrew/ships/ship_<suffix>.dmm`. Include the
   permanent helm, spawn pod and its clear exit, routes between rooms, propulsion,
   and the systems that every fitout needs. Decide which power and atmos equipment
   stays in the hull and which must be supplied by every module for a given slot.
4. **Place a ship upgrade marker for each slot.** Use
   `/obj/modular_map_root/ship_upgrade` with `key` equal to the slot ID. Keep the
   slots' rectangles from overwriting each other or permanent hull features.
5. **Create themes and modules** in `voidcrew/modules/ship_upgrades/ships/`.
   Set their `for_ship` to the new base template. Follow the module and theme
   steps above. For a hull with no selectable themes, define `job_slots` on the
   hull and leave its modules' `for_theme` unset.
6. **Document each slot beside its module definitions.** Record the footprint,
   marker and connector coordinates, reserved tiles, entry lanes, and which
   infrastructure and equipment every option must retain or supply.
7. **Include the new DM files in `tgstation.dme`.** Check the base `suffix` and
   every theme's `template_suffix` point to the intended hull DMMs.

Player shipyard visibility is controlled by
[`is_player_purchasable_ship()`](ship_catalog_ui.dm).
Normal modular hulls need `has_upgrade_slots` and a nonempty slot or theme list,
with `player_hidden = FALSE`. `player_hidden = TRUE` keeps development fixtures
off the shelf. `force_purchasable` is for deliberately listed exceptions such as
fixed novelty hulls; it is not part of the normal modular hull setup.

Eligible modular hulls also enter the roundstart fleet, which can roll paid
themes and modules without checking player unlocks. Every allowed combination
must work, including its crew jobs and essential systems.

## Areas and ship ownership

Room boundaries, upgrade slots and areas are independent. A fixed room can have
its own area without being an upgrade slot, and a module can inherit the hull's
area without defining one. The mobile docking port's `area_type` must include
the ship's mapped area subtypes so its rooms belong to the same shuttle.

For example, [Goon's definitions](../../mapping/shuttles/goon.dm) contain:

```dm
/area/shuttle/voidcrew/goon/bridge
	name = "Bridge"
	icon_state = "bridge"
```

Its `/a`, `/b`, `/c` and `/d` children inherit that display name. The Goon mobile
port uses `/area/shuttle/voidcrew/goon` as `area_type`, which covers those bridge
areas and the other Goon room areas. Reusing a display name does not merge area
types; changing `name` alone does not assign map tiles or establish ownership.

When defining another room manually, use a distinct subtype under the actual
port's area root, include its DM file, and assign it to the intended map tiles.
Check its power and alarm grouping and provide the required equipment. A ship's
file identifier is not sufficient to infer an existing port's area root.

The Workshop's area action resolves this root and creates an included subtype.
Area assignment changes neither turfs nor objects. Most modules should retain
`/area/template_noop` so their tiles keep the hull's areas. If a module deliberately
replaces an area, check ownership and infrastructure in every supported theme.

For docking, use the [port helper](MAPPER_GUIDE.md#set-up-the-docking-port) or
configure the matching mobile port manually. Its map `dir`, `port_direction`
and `preferred_direction` work together; copying another hull's values is only
valid when its orientation and geometry match. The helper sets these for the
selected entrance. Runtime docking still needs a playtest.

## Costs and starting equipment

Use the current DM definitions when comparing prices. Hull costs are stored in
`part_requirements`; theme and module costs are stored in `part_cost`, using
`PART_CLASS_COMBAT`, `PART_CLASS_SCIENCE`, `PART_CLASS_TRADE` and `PART_CLASS_MISC`.
These are one-time unlock costs.

The current Goon, Kilo, Delta, Scarab and Phalanx templates have empty
`part_requirements` and therefore free hull unlocks. The old hull tile-count
formula and paid-hull ladder no longer describe those definitions. Themes and
modules still have their own costs; compare a proposed option with similar
equipment on the same hull rather than deriving a price from room size alone.

Default themes and modules are available without a purchase. An optional theme
or module with an empty `part_cost` has a zero-cost unlock, but still goes
through the unlock action unless `FREE_SHIPS` is enabled. Do not mark multiple
options as defaults just to make them free.

Keep one permanent spawn cryopod in the hull and its approach clear; ordinary
modules should not add extra spawn pods. Starting armor is limited to the
security closet's vest and helmet: do not put `armory1`, `armory2` or `armory3`
closets in ordinary starting modules. Specialist armory content needs its own
balance review. Price alone does not keep equipment out of a roundstart ship.

### Parts income

The [participation grant](../shuttle/ship_parts/user_client.dm) currently awards
one random-class part for having played a character. It is a direct account
grant. Physical parts from exploration and events use the
[extraction system](../../../wiki/content/ship-parts.md).
Income depends on the activity and successful extraction; a fixed parts-per-round
estimate is not a reliable basis for pricing a new module.

## Regenerate ship previews

The shipyard displays **committed images**, composed according to the selected
hull and rooms. It does not render changed DMMs when the UI opens.

Run from the repository root after adding or changing a modular hull, module,
themed room file, or preview-relevant registration:

```sh
python tools/ship_previews/generate_ship_previews.py
```

The [generator](../../../tools/ship_previews/generate_ship_previews.py) needs
Python with Pillow and `dmm-tools`. Set the `DMM_TOOLS` environment variable to
your executable's full path. For example, in PowerShell, replacing the path:

```powershell
$env:DMM_TOOLS = 'C:/path/to/dmm-tools.exe'
python tools/ship_previews/generate_ship_previews.py
```

It scans modular hull markers, registered module filenames and their themed
variants, then writes `previews/*.png` and `previews/manifest.json`. Allow several
minutes for the full run. Wait for the final `wrote ...manifest.json` message,
check the manifest's modification time, and inspect the expected image changes.
An early per-map completion message does not mean the whole run is finished.

Commit the generated changes alongside the DMM and DM changes. Check the
assembled preview in the shipyard; a standalone room image cannot reveal all
overlaps with the hull. Previews also do not prove that power, atmos, access or
runtime sprites work in game.

### Preview discovery limits

The current generator discovers hulls by upgrade markers in `ship_*.dmm`, plus
explicit extra hulls. It collects module `map_file` declarations from
`voidcrew/modules/ship_upgrades/ships/*.dm`, then looks for themed DMMs beside
each base filename. It does not discover every included DM file through the DME.

In particular, room registrations added to a hand-written ship under
`voidcrew/modules/ship_upgrades/workshop/` are outside that scan. Before shipping
those additions, the generator needs to discover those registrations as well.
Check for an entry under the module's exact `map_file` in the manifest; a
successful generator run alone does not establish coverage. Do not duplicate
runtime module registrations just to make the preview scanner find them.

## Validate and submit

For an optional static check, run the fork's `shipcheck.exe` against the saved
checkout. In PowerShell, replacing the editor directory:

```powershell
& 'C:/path/to/StrongDMM/shipcheck.exe' -dme './tgstation.dme' -hull delta -all
```

Use the hull's type suffix in place of `delta`, or omit `-hull` to check the fleet.
The command uses the editor's assembly code and reports missing files, unknown
map types and assembly/access findings. `-all` tests each alternative module
against the other default modules in each theme; it does **not** enumerate
every combination of alternatives. It also does not simulate the DM runtime,
power, atmos or docking. Review reported issues even when it exits successfully.

- [ ] Changed DMMs are in TGM format and pass the focused checks in the
  [general mapping guide](../../GUIDES/mapping.md#check-an-edit).
- [ ] Every hull marker has the intended slot key, and every room has one
  correctly placed connector.
- [ ] Every effective slot has one usable default; every allowed module/theme
  combination resolves to an existing map.
- [ ] Hull reserve tiles, cryopod exits and door approaches remain clear in the
  assembled ship. No machinery, APCs or other hull objects are duplicated.
- [ ] Hull and module infrastructure together provide power and breathable air
  for every fitout. Added jobs have equipment and usable access.
- [ ] New DM files are included, and the project builds through Juke.
- [ ] Previews have been regenerated and the expected PNG and manifest changes
  are included.
- [ ] The affected themes and modules have been loaded and checked in game.

### Test in game

Follow the [shipyard playtest procedure](MAPPER_GUIDE.md#test-in-game) in the
mapper guide. Test optional choices through **Open Shipyard**; admin
**Spawn Specific Ship** only exercises the default spawn path.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Module missing from the selector | Its DM file is included, `id` is unique within the ship, `for_ship` is correct, `slot` is in the effective slot list, and `for_theme` matches the selected theme ID. |
| Slot is empty after launch | Hull marker `key`, selection/default module, and themed/base file existence. Missing module files can leave an empty slot without a visible error. |
| Room is shifted or cuts through a wall | Connector and hull marker coordinates, room dimensions, and noop padding. The marker is an anchor, not automatically the bottom-left corner. |
| Duplicate machines or furniture inside walls | Both hull and module place objects at the same coordinates, or an object was added on a reserved noop tile. |
| Ship appears in admin spawning but not the shipyard | `player_hidden`, `has_upgrade_slots`, slot/theme lists and the catalog's purchasability rules. |
| Theme missing or wrong hull loads | Included theme definition, unique `id`, `for_ship`, `available_themes`, `template_suffix` and the corresponding hull filename. |
| Added crew job is missing | Effective module selection, `job_slots_add`, and an outfit with a valid `jobtype`. |
| Preview shows an older layout or omits a new room | Regenerate assets; verify the selected theme uses the file you edited, the registration is covered by preview discovery, and the expected PNGs and manifest entries are present. |
| Workshop save stops after a DM edit | Check the reported file against the project metadata and disk changes; see [source ownership](#workshop-files-and-source-ownership). |
| Ship is unpowered or players cannot leave spawn | Inspect hull and module together against the ship's infrastructure and reserve-tile notes, including every changed theme. |

For exact behavior, see the [datum definitions and selection helpers](_ship_upgrades.dm),
[ship module loader](modular_map_root_ship.dm),
[connector alignment](../../../code/modules/mapping/modular_map_loader/modular_map_loader.dm),
and [shipyard backend](ship_upgrade_selector.dm).
