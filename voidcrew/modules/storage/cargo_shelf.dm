/**
 * Cargo shelf: a steel shelving unit that stacks crates vertically on a single tile.
 *
 * Ported from Monkestation (monkestation/code/modules/shelves/shelf.dm), which itself took it
 * from Shiptest (https://github.com/shiptest-ss13/Shiptest/pull/2374).
 * Source: https://github.com/Monkestation/Monkestation2.0
 * The code is AGPL and the sprites are CC BY-SA 3.0, the same licences as this repository.
 *
 * Differences from the original:
 * - Built from four iron sheets and takes apart into the same four, nothing more.
 * - Crates may only be loaded and unloaded next to the shelf, and a shelf can't be built on a door.
 * - Slots, layers and the display list are kept in step by Entered() and Exited(), so a crate that
 *   leaves any way at all (deleted, moved by an admin) frees its slot.
 * - Taking a shelf apart sets its crates down gently. A shelf that is destroyed drops them in a heap.
 *   Crates never break open or fall apart on their own, so a locked crate can't be burst by shooting
 *   the shelf under it.
 * - Explosions reach the crates on a shelf the same way they reach crates on the floor.
 */

/// How many crates one shelf holds.
#define CARGO_SHELF_CAPACITY 3
/// How long loading or unloading one crate takes.
#define CARGO_SHELF_USE_DELAY (1 SECONDS)
/// Pixels between one shelf level and the next. Kept to 10 so most of each crate stays on the tile to click.
#define CARGO_SHELF_STEP 10
/// Iron sheets in a set of cargo shelf parts. Taking the parts apart gives all of them back, no more.
#define CARGO_SHELF_SHEET_COST 4

/obj/structure/cargo_shelf
	name = "cargo shelf"
	desc = "A steel shelf for stacking crates."
	icon = 'voidcrew/icons/obj/storage/cargo_shelf.dmi'
	icon_state = "shelf_base"
	density = TRUE
	anchored = TRUE
	max_integrity = 50
	/// How many crates it holds.
	var/capacity = CARGO_SHELF_CAPACITY
	/// How long it takes to load or unload one crate.
	var/use_delay = CARGO_SHELF_USE_DELAY
	/// One entry per level, lowest first: the crate standing on that level, or null.
	var/list/shelf_contents

/obj/structure/cargo_shelf/Initialize(mapload)
	// Ahead of the parent so a crate that arrives during init already has somewhere to go.
	shelf_contents = new /list(capacity)
	. = ..()
	update_appearance(UPDATE_OVERLAYS)

/obj/structure/cargo_shelf/Destroy()
	// Whatever is still inside is deleted with the shelf. Exited() tolerates the list being gone.
	shelf_contents = null
	return ..()

/// The extra shelf plates above the base, one per level past the first.
/obj/structure/cargo_shelf/update_overlays()
	. = ..()
	for(var/level in 1 to (capacity - 1))
		var/mutable_appearance/plate = mutable_appearance(icon, "shelf_stack", plate_layer(level))
		plate.pixel_y = CARGO_SHELF_STEP * level
		. += plate

/// The layer a crate on this level is drawn at. From the third level up the crates stand out past
/// the tile, so mobs walk underneath them.
/obj/structure/cargo_shelf/proc/crate_layer(level)
	if(level >= 3)
		return ABOVE_MOB_LAYER + 0.02 * (level - 1)
	return BELOW_OBJ_LAYER + 0.02 * (level - 1)

/// The layer of the plate between this level and the one above it: over the lower crate, under the upper.
/obj/structure/cargo_shelf/proc/plate_layer(level)
	if(level >= 3)
		return ABOVE_MOB_LAYER + 0.02 * level - 0.01
	return BELOW_OBJ_LAYER + 0.02 * level - 0.01

/obj/structure/cargo_shelf/examine(mob/user)
	. = ..()
	if(!length(contents))
		return
	. += span_notice("It holds:")
	for(var/obj/structure/closet/crate/crate in contents)
		. += "&nbsp;&nbsp;[icon2html(crate, user)] [crate]"

/obj/structure/cargo_shelf/wrench_act(mob/living/user, obj/item/tool)
	tool.play_tool_sound(src)
	if(tool.use_tool(src, user, 3 SECONDS))
		deconstruct(TRUE)
	return ITEM_INTERACT_SUCCESS

/// Whether this crate can be lifted onto the shelf at all.
/obj/structure/cargo_shelf/proc/can_hold(obj/structure/closet/crate/crate)
	return !QDELETED(crate) && !crate.anchored && isturf(crate.loc)

/// Loads a crate from the floor, closing it first. Returns whether it went on the shelf.
/obj/structure/cargo_shelf/proc/load_crate(obj/structure/closet/crate/crate, mob/living/user)
	if(!shelf_contents.Find(null))
		balloon_alert(user, "full")
		return FALSE
	if(!can_hold(crate))
		return FALSE
	if(!do_after(user, use_delay, target = crate))
		return FALSE
	// Somebody else may have filled the last slot or taken the crate in the meantime.
	if(!can_hold(crate) || !shelf_contents.Find(null) || !Adjacent(crate))
		return FALSE
	if(crate.opened && !crate.close(user))
		return FALSE
	return insert_crate(crate)

/// Puts a crate on the lowest free level. Entered() does the placing. Returns whether it went in.
/obj/structure/cargo_shelf/proc/insert_crate(obj/structure/closet/crate/crate)
	if(QDELETED(crate) || !shelf_contents.Find(null))
		return FALSE
	crate.forceMove(src)
	return crate.loc == src

/// Sets a crate from the shelf down on the floor beside it. Returns whether it came out.
/obj/structure/cargo_shelf/proc/unload_crate(obj/structure/closet/crate/crate, mob/living/user, turf/unload_turf)
	if(QDELETED(crate) || crate.loc != src || !isturf(unload_turf))
		return FALSE
	if(unload_turf == get_turf(src) || !Adjacent(unload_turf) || !unload_turf.Enter(crate))
		balloon_alert(user, "no room")
		return FALSE
	if(!do_after(user, use_delay, target = src))
		return FALSE
	if(QDELETED(crate) || crate.loc != src)
		return FALSE
	// The floor may have filled up while the crate was being lifted down.
	if(!unload_turf.Enter(crate))
		balloon_alert(user, "no room")
		return FALSE
	crate.forceMove(unload_turf)
	return TRUE

/obj/structure/cargo_shelf/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(!istype(arrived, /obj/structure/closet/crate))
		return
	RegisterSignal(arrived, COMSIG_MOUSEDROP_ONTO, PROC_REF(crate_unload))
	var/level = shelf_contents.Find(arrived) || shelf_contents.Find(null)
	if(level)
		shelf_contents[level] = arrived
		arrived.pixel_y = CARGO_SHELF_STEP * (level - 1)
		arrived.layer = crate_layer(level)
	vis_contents += arrived

/obj/structure/cargo_shelf/Exited(atom/movable/gone, direction)
	. = ..()
	if(!istype(gone, /obj/structure/closet/crate))
		return
	UnregisterSignal(gone, COMSIG_MOUSEDROP_ONTO)
	vis_contents -= gone
	var/level = shelf_contents?.Find(gone)
	if(level)
		shelf_contents[level] = null
	// Back to how a crate looks on the floor, whichever way it left. The crate's own update sets its
	// layer (a closed crate is drawn above the closet default).
	gone.pixel_y = initial(gone.pixel_y)
	if(!QDELETED(gone))
		gone.update_icon()

/// Signal registered on each stored crate, so it can be pulled off the shelf by dragging the crate
/// itself instead of the shelf. Only onto the floor right beside the shelf.
/obj/structure/cargo_shelf/proc/crate_unload(obj/structure/closet/crate/source, atom/over, mob/user)
	SIGNAL_HANDLER
	if(!istype(user) || !isopenturf(over) || !Adjacent(over))
		return
	if(!user.can_perform_action(src, FORBID_TELEKINESIS_REACH))
		return
	INVOKE_ASYNC(src, PROC_REF(unload_crate), source, user, over)
	return COMPONENT_CANCEL_MOUSEDROP_ONTO

/// Dragging the shelf onto the floor lifts down its top crate.
/obj/structure/cargo_shelf/mouse_drop_dragged(atom/over, mob/user, src_location, over_location, params)
	if(!isopenturf(over))
		return
	for(var/level in capacity to 1 step -1)
		var/obj/structure/closet/crate/crate = shelf_contents[level]
		if(crate)
			unload_crate(crate, user, over)
			return

/// Dragging a crate onto the shelf loads it.
/obj/structure/cargo_shelf/mouse_drop_receive(atom/dropped, mob/living/user, params)
	if(!istype(dropped, /obj/structure/closet/crate))
		return
	load_crate(dropped, user)

/// Someone shut inside a stored crate can shove it off the shelf, slowly.
/obj/structure/cargo_shelf/relay_container_resist_act(mob/living/user, obj/container)
	if(DOING_INTERACTION_WITH_TARGET(user, container))
		return
	to_chat(user, span_notice("You start shoving [container] off [src]..."))
	if(!do_after(user, 30 SECONDS, target = container))
		return
	if(user.stat != CONSCIOUS || user.loc != container || container.loc != src)
		return
	container.forceMove(drop_location())
	step_rand(container, 1)
	to_chat(user, span_notice("You shove [container] off [src]."))
	container.visible_message(span_warning("[container] falls off [src]!"), blind_message = span_hear("You hear a thud."), ignored_mobs = user)

/// A shelf that is taken apart or destroyed sets its crates down on the floor first, even if it leaves no parts.
/obj/structure/cargo_shelf/handle_deconstruct(disassembled = TRUE)
	release_crates(disassembled)
	return ..()

/obj/structure/cargo_shelf/atom_deconstruct(disassembled = TRUE)
	set_density(FALSE)
	var/obj/item/rack_parts/cargo_shelf/parts = new(drop_location())
	transfer_fingerprints_to(parts)

/// Puts every crate on the floor. Disassembled, they are set down in place; destroyed, they tumble
/// and some lids fall open.
/obj/structure/cargo_shelf/proc/release_crates(disassembled)
	var/turf/dump_turf = drop_location()
	if(!dump_turf)
		return
	// A snapshot: each crate leaves contents as it is set down.
	for(var/obj/structure/closet/crate/crate in contents.Copy())
		crate.forceMove(dump_turf)
		if(disassembled)
			continue
		step(crate, pick(GLOB.alldirs))
		crate.SpinAnimation(rand(4, 7), 1)
		// Fails quietly on a locked or welded crate.
		if(prob(30) && crate.open())
			crate.visible_message(span_warning("[crate]'s lid falls open!"))

/// Crates on a shelf are hit by a blast like crates on the floor.
/obj/structure/cargo_shelf/contents_explosion(severity, target)
	switch(severity)
		if(EXPLODE_DEVASTATE)
			SSexplosions.high_mov_atom += contents
		if(EXPLODE_HEAVY)
			SSexplosions.med_mov_atom += contents
		if(EXPLODE_LIGHT)
			SSexplosions.low_mov_atom += contents

/obj/item/rack_parts/cargo_shelf
	name = "cargo shelf parts"
	desc = "Parts of a cargo shelf."
	icon = 'voidcrew/icons/obj/storage/cargo_shelf.dmi'
	icon_state = "rack_parts"
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * CARGO_SHELF_SHEET_COST)

// The rack parts' screentips name racks, and the rules keep control hints out of the game.
/obj/item/rack_parts/cargo_shelf/add_context(atom/source, list/context, obj/item/held_item, mob/living/user)
	return NONE

/// The whole cost comes back, the same sheets it was made from. Not calling the parent, which
/// would give back a rack's one sheet.
/obj/item/rack_parts/cargo_shelf/atom_deconstruct(disassembled = TRUE)
	new /obj/item/stack/sheet/iron(drop_location(), CARGO_SHELF_SHEET_COST)

/// Whether a shelf can go up on this tile.
/obj/item/rack_parts/cargo_shelf/proc/can_build_on(turf/tile, mob/user)
	if(!isturf(user.loc) || tile.is_blocked_turf(exclude_mobs = TRUE) || locate(/obj/machinery/door) in tile)
		balloon_alert(user, "no room")
		return FALSE
	return TRUE

/obj/item/rack_parts/cargo_shelf/attack_self(mob/user)
	if(building)
		return
	var/turf/build_turf = get_turf(user)
	if(!can_build_on(build_turf, user))
		return
	building = TRUE
	to_chat(user, span_notice("You start assembling a cargo shelf..."))
	if(do_after(user, 5 SECONDS, target = user, progress = TRUE) && can_build_on(build_turf, user) && user.temporarilyRemoveItemFromInventory(src))
		var/obj/structure/cargo_shelf/shelf = new(build_turf)
		user.visible_message(span_notice("[user] assembles \a [shelf]."), span_notice("You assemble \a [shelf]."))
		shelf.add_fingerprint(user)
		qdel(src)
		return
	building = FALSE

/// The shelf's recipe, added to iron sheets below.
GLOBAL_LIST_INIT(cargo_shelf_recipes, list(
	new /datum/stack_recipe("cargo shelf parts", /obj/item/rack_parts/cargo_shelf, CARGO_SHELF_SHEET_COST, category = CAT_FURNITURE),
))

/// Chained onto the upstream list, so the iron sheet recipes stay untouched.
/obj/item/stack/sheet/iron/get_main_recipes()
	. = ..()
	. += GLOB.cargo_shelf_recipes

#undef CARGO_SHELF_CAPACITY
#undef CARGO_SHELF_USE_DELAY
#undef CARGO_SHELF_STEP
#undef CARGO_SHELF_SHEET_COST
