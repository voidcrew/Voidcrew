// Ship Combat Missiles - Modular Construction System
// Missiles are constructed by:
// 1. Building a missile frame in a protolathe
// 2. Wiring the frame with cable
// 3. Inserting a tracking circuit
// 4. Inserting a bomb core (warhead)
// 5. Dragging the completed missile to a launcher
// 6. Loading it into the launcher (takes time)

// ========== MISSILE TRACKING CIRCUIT ==========
// Required component that enables the missile to lock onto targets

/obj/item/electronics/ship_missile_tracking
	name = "missile tracking circuit"
	desc = "A guidance system circuit for ship missiles. Insert into a wired missile frame before adding the warhead."
	icon_state = "boris_recharging" // Placeholder - can be changed later
	/// Time to insert this circuit into a frame
	var/insert_time = 2 SECONDS

/obj/item/electronics/ship_missile_tracking/examine(mob/user)
	. = ..()
	. += span_notice("This circuit enables target tracking and guidance for ship missiles.")

// ========== MISSILE BOMB CORES ==========
// Warheads that use TG's bomb core system for detonation

/obj/item/bombcore/missile
	name = "standard missile warhead"
	desc = "A warhead designed for ship-to-ship missiles. Insert into a missile frame with a tracking circuit installed."
	icon_state = "bombcore"
	/// Short name for use in missile naming and UI
	var/payload_type = "standard"
	/// Damage dealt on impact (used by ship combat system)
	var/ship_damage = MISSILE_DAMAGE_STANDARD
	/// The missile effect type spawned when fired
	var/missile_effect_type = /obj/effect/ship_missile
	/// Icon state for the flying missile effect
	var/missile_icon_state = "missile"
	/// Time to insert this warhead into a frame
	var/insert_time = 3 SECONDS
	// Explosion ranges - using bomb core's built-in system
	range_heavy = 2
	range_medium = 3
	range_light = 5
	range_flame = 3

/obj/item/bombcore/missile/examine(mob/user)
	. = ..()
	. += span_notice("Ship damage output: [ship_damage]")
	. += span_notice("Explosion radius: [range_light] tiles")

/obj/item/bombcore/missile/light
	name = "light missile warhead"
	desc = "A smaller warhead for missiles. Less damage but cheaper to produce."
	payload_type = "light"
	ship_damage = MISSILE_DAMAGE_LIGHT
	missile_icon_state = "smissile"
	insert_time = 2 SECONDS
	range_heavy = 1
	range_medium = 2
	range_light = 3
	range_flame = 1

/obj/item/bombcore/missile/heavy
	name = "heavy missile warhead"
	desc = "A massive warhead for missiles. Devastating damage but expensive."
	w_class = WEIGHT_CLASS_BULKY
	payload_type = "heavy"
	ship_damage = MISSILE_DAMAGE_HEAVY
	insert_time = 5 SECONDS
	range_heavy = 3
	range_medium = 5
	range_light = 7
	range_flame = 4

/obj/item/bombcore/missile/emp
	name = "EMP missile warhead"
	desc = "An electromagnetic pulse warhead. Disables electronics on impact."
	payload_type = "EMP"
	ship_damage = MISSILE_DAMAGE_LIGHT
	missile_effect_type = /obj/effect/ship_missile/emp
	insert_time = 4 SECONDS
	range_heavy = 0
	range_medium = 0
	range_light = 1
	range_flame = 0
	/// EMP heavy range
	var/emp_heavy = 4
	/// EMP light range
	var/emp_light = 8

/obj/item/bombcore/missile/emp/detonate()
	// EMP effect instead of explosion
	empulse(src, emp_heavy, emp_light)
	if(loc && istype(loc, /obj/structure/ship_missile))
		qdel(loc)
	qdel(src)

/obj/item/bombcore/missile/chemical
	name = "chemical missile warhead"
	desc = "An empty chemical warhead casing. Insert up to two beakers or bottles, then load into a missile frame. On impact, the reagents will mix and splash over a wide area."
	icon = 'icons/obj/weapons/grenade.dmi'
	icon_state = "chemg"
	payload_type = "chemical"
	ship_damage = MISSILE_DAMAGE_LIGHT
	missile_effect_type = /obj/effect/ship_missile/chemical
	insert_time = 4 SECONDS
	range_heavy = 0
	range_medium = 0
	range_light = 1
	range_flame = 0
	/// Beakers inserted into this warhead
	var/list/obj/item/beakers = list()
	/// Max beakers allowed
	var/max_beakers = 2
	/// Splash radius on impact
	var/affected_area = 5
	/// Temperature added to reagents on impact
	var/ignition_temp = 100

/obj/item/bombcore/missile/chemical/Destroy()
	QDEL_LIST(beakers)
	return ..()

/obj/item/bombcore/missile/chemical/examine(mob/user)
	. = ..()
	if(!length(beakers))
		. += span_notice("It's empty. Use beakers or bottles on it to load reagents.")
	else
		. += span_notice("Contains [length(beakers)]/[max_beakers] containers:")
		for(var/obj/item/container in beakers)
			if(container.reagents)
				. += span_notice("- [container.name]: [container.reagents.total_volume]u")
	. += span_notice("Splash radius: [affected_area] tiles")

/obj/item/bombcore/missile/chemical/attackby(obj/item/W, mob/user, list/modifiers)
	// Insert beakers/bottles
	if(istype(W, /obj/item/reagent_containers/cup/beaker) || istype(W, /obj/item/reagent_containers/cup/bottle))
		if(length(beakers) >= max_beakers)
			to_chat(user, span_warning("[src] can't hold any more containers!"))
			return
		if(!user.transferItemToLoc(W, src))
			return
		beakers += W
		to_chat(user, span_notice("You insert [W] into [src]. ([length(beakers)]/[max_beakers])"))
		playsound(src, 'sound/machines/click.ogg', 50, TRUE)
		update_appearance()
		return

	// Crowbar to remove beakers
	if(W.tool_behaviour == TOOL_CROWBAR)
		if(!length(beakers))
			to_chat(user, span_warning("[src] has no containers to remove!"))
			return
		to_chat(user, span_notice("You pry the containers out of [src]."))
		for(var/obj/item/container in beakers)
			container.forceMove(drop_location())
		beakers.Cut()
		update_appearance()
		return

	return ..()

/obj/item/bombcore/missile/chemical/update_icon_state()
	. = ..()
	if(length(beakers))
		icon_state = "chemg_locked"
	else
		icon_state = "chemg"

/obj/item/bombcore/missile/chemical/Exited(atom/movable/gone, direction)
	. = ..()
	beakers -= gone

/obj/item/bombcore/missile/chemical/detonate()
	// Chemical splash instead of explosion - handled by missile effect
	// Small explosion for physical impact
	explosion(src, 0, 0, range_light, range_flame)
	if(loc && istype(loc, /obj/structure/ship_missile))
		qdel(loc)
	qdel(src)

// ========== MISSILE FRAME ==========
// The missile body that components are installed into

/obj/structure/ship_missile
	name = "missile frame"
	desc = "An unwired missile frame. Use cable coil to wire it up."
	icon = 'voidcrew/icons/obj/supplypods.dmi'
	icon_state = "missile_nowire"
	drag_slowdown = 1.5
	pixel_x = -16 // 2x1 sprite offset
	pixel_y = -16 // Vertically center the tall sprite on its tile
	anchored = FALSE
	density = FALSE
	max_integrity = 100
	/// Current construction state
	var/construction_state = MISSILE_STATE_UNWIRED
	/// The tracking circuit installed in this missile
	var/obj/item/electronics/ship_missile_tracking/tracking
	/// The bomb core (warhead) installed in this missile
	var/obj/item/bombcore/missile/warhead
	/// Time to load this missile into a launcher
	var/load_time = 4 SECONDS
	/// Whether this missile has already detonated (prevents double explosions)
	var/detonated = FALSE

/obj/structure/ship_missile/Initialize(mapload)
	. = ..()
	// Rotate 90 degrees to lay on its side
	var/matrix/M = matrix()
	M.Turn(90)
	transform = M
	update_appearance()

// ========== PRE-ARMED MISSILE SUBTYPES ==========
// These spawn already armed with their warhead - for admin spawning and cargo

/obj/structure/ship_missile/armed
	construction_state = MISSILE_STATE_ARMED
	/// The warhead type to spawn with
	var/warhead_path = /obj/item/bombcore/missile

/obj/structure/ship_missile/armed/Initialize(mapload)
	. = ..()
	tracking = new /obj/item/electronics/ship_missile_tracking(src)
	warhead = new warhead_path(src)
	update_appearance()

/obj/structure/ship_missile/armed/light
	warhead_path = /obj/item/bombcore/missile/light

/obj/structure/ship_missile/armed/standard
	warhead_path = /obj/item/bombcore/missile

/obj/structure/ship_missile/armed/heavy
	warhead_path = /obj/item/bombcore/missile/heavy

/obj/structure/ship_missile/armed/emp
	warhead_path = /obj/item/bombcore/missile/emp

/obj/structure/ship_missile/Destroy()
	if(tracking)
		QDEL_NULL(tracking)
	if(warhead)
		QDEL_NULL(warhead)
	return ..()

// Armed missiles explode when destroyed
/obj/structure/ship_missile/atom_destruction(damage_flag)
	if(construction_state == MISSILE_STATE_ARMED && warhead && !detonated)
		detonate()
	return ..()

/// Detonates the missile using the bomb core's detonation
/obj/structure/ship_missile/proc/detonate()
	if(detonated)
		return
	detonated = TRUE
	if(!warhead)
		return

	visible_message(span_userdanger("[src] detonates!"))
	playsound(src, 'sound/effects/explosion/explosion1.ogg', 100, TRUE)

	// Use the bomb core's detonation - it will handle cleanup
	warhead.detonate()

/obj/structure/ship_missile/examine(mob/user)
	. = ..()
	switch(construction_state)
		if(MISSILE_STATE_UNWIRED)
			. += span_notice("It needs to be wired up.")
		if(MISSILE_STATE_WIRED)
			. += span_notice("It needs a tracking circuit installed.")
			. += span_notice("Use a tracking circuit on it.")
		if(MISSILE_STATE_TRACKING)
			. += span_notice("It's ready for a warhead.")
			. += span_notice("Use a missile warhead on it.")
		if(MISSILE_STATE_PAYLOAD)
			. += span_notice("It has [warhead] installed.")
			. += span_notice("Use a screwdriver to seal it.")
		if(MISSILE_STATE_ARMED)
			. += span_notice("It's armed with [warhead].")
			. += span_notice("Damage: [warhead.ship_damage]")
	. += span_warning("It looks heavy.")

/obj/structure/ship_missile/update_name(updates)
	. = ..()
	switch(construction_state)
		if(MISSILE_STATE_ARMED)
			if(warhead)
				name = "[warhead.payload_type] missile"
			else
				name = "armed missile"
		else
			name = "missile frame"

/obj/structure/ship_missile/update_desc(updates)
	. = ..()
	switch(construction_state)
		if(MISSILE_STATE_UNWIRED)
			desc = "An unwired missile frame. Use cable coil to wire it up."
		if(MISSILE_STATE_WIRED)
			desc = "A wired missile frame. Needs a tracking circuit."
		if(MISSILE_STATE_TRACKING)
			desc = "A missile frame with tracking installed. Ready for a warhead."
		if(MISSILE_STATE_PAYLOAD)
			desc = "A missile with warhead installed. Needs to be sealed with a screwdriver."
		if(MISSILE_STATE_ARMED)
			desc = "A fully armed missile. Drag it to a launcher to load."

/obj/structure/ship_missile/update_icon_state()
	. = ..()
	switch(construction_state)
		if(MISSILE_STATE_UNWIRED)
			icon_state = "missile_nowire"
		if(MISSILE_STATE_WIRED)
			icon_state = "missile_wired"
		if(MISSILE_STATE_TRACKING)
			icon_state = "missile_circuit"
		if(MISSILE_STATE_PAYLOAD)
			icon_state = "missile_core"
		if(MISSILE_STATE_ARMED)
			icon_state = "missile"

// Can't pick it up - too heavy, must drag
/obj/structure/ship_missile/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	to_chat(user, span_warning("[src] is too heavy to pick up! You'll need to drag it."))
	return TRUE

// Construction steps
/obj/structure/ship_missile/attackby(obj/item/W, mob/user, list/modifiers)
	// Wiring with cable
	if(istype(W, /obj/item/stack/cable_coil))
		if(construction_state != MISSILE_STATE_UNWIRED)
			to_chat(user, span_warning("[src] is already wired!"))
			return
		var/obj/item/stack/cable_coil/cable = W
		if(cable.get_amount() < 5)
			to_chat(user, span_warning("You need at least 5 cable pieces."))
			return

		to_chat(user, span_notice("You begin wiring [src]..."))
		if(!do_after(user, 2 SECONDS, src))
			to_chat(user, span_warning("You stop wiring the missile."))
			return

		if(construction_state != MISSILE_STATE_UNWIRED)
			return
		if(!cable.use(5))
			return

		construction_state = MISSILE_STATE_WIRED
		update_appearance()
		to_chat(user, span_notice("You wire up [src]."))
		playsound(src, 'sound/machines/click.ogg', 50, TRUE)
		return

	// Installing tracking circuit
	if(istype(W, /obj/item/electronics/ship_missile_tracking))
		if(construction_state == MISSILE_STATE_UNWIRED)
			to_chat(user, span_warning("[src] needs to be wired first!"))
			return
		if(construction_state != MISSILE_STATE_WIRED)
			to_chat(user, span_warning("[src] already has a tracking circuit installed!"))
			return

		var/obj/item/electronics/ship_missile_tracking/new_tracking = W
		to_chat(user, span_notice("You begin installing [new_tracking] into [src]..."))

		if(!do_after(user, new_tracking.insert_time, src))
			to_chat(user, span_warning("You stop installing the tracking circuit."))
			return

		if(construction_state != MISSILE_STATE_WIRED)
			return
		if(QDELETED(new_tracking) || new_tracking.loc != user)
			return

		if(!user.transferItemToLoc(new_tracking, src))
			return

		tracking = new_tracking
		construction_state = MISSILE_STATE_TRACKING
		update_appearance()
		to_chat(user, span_notice("You install [tracking] into [src]."))
		playsound(src, 'sound/machines/click.ogg', 50, TRUE)
		return

	// Inserting warhead (bomb core)
	if(istype(W, /obj/item/bombcore/missile))
		if(construction_state < MISSILE_STATE_TRACKING)
			if(construction_state == MISSILE_STATE_UNWIRED)
				to_chat(user, span_warning("[src] needs to be wired first!"))
			else
				to_chat(user, span_warning("[src] needs a tracking circuit installed first!"))
			return
		if(construction_state == MISSILE_STATE_ARMED)
			to_chat(user, span_warning("[src] already has a warhead installed!"))
			return

		var/obj/item/bombcore/missile/new_warhead = W
		to_chat(user, span_notice("You begin inserting [new_warhead] into [src]..."))

		if(!do_after(user, new_warhead.insert_time, src))
			to_chat(user, span_warning("You stop inserting the warhead."))
			return

		if(construction_state != MISSILE_STATE_TRACKING)
			return
		if(QDELETED(new_warhead) || new_warhead.loc != user)
			return

		if(!user.transferItemToLoc(new_warhead, src))
			return

		warhead = new_warhead
		construction_state = MISSILE_STATE_PAYLOAD
		update_appearance()
		to_chat(user, span_notice("You insert [warhead] into [src]. Use a screwdriver to seal it."))
		playsound(src, 'sound/machines/click.ogg', 50, TRUE)
		return

	// Wirecutters to remove wiring
	if(W.tool_behaviour == TOOL_WIRECUTTER)
		if(construction_state == MISSILE_STATE_UNWIRED)
			to_chat(user, span_warning("[src] isn't wired!"))
			return
		if(construction_state > MISSILE_STATE_WIRED)
			to_chat(user, span_warning("Remove the tracking circuit first!"))
			return
		to_chat(user, span_notice("You cut the wiring from [src]."))
		new /obj/item/stack/cable_coil(drop_location(), 5)
		construction_state = MISSILE_STATE_UNWIRED
		update_appearance()
		return

	// Screwdriver to seal/unseal the missile or remove tracking circuit
	if(W.tool_behaviour == TOOL_SCREWDRIVER)
		// Seal the missile after payload insertion
		if(construction_state == MISSILE_STATE_PAYLOAD)
			to_chat(user, span_notice("You begin sealing [src]..."))
			if(!do_after(user, 2 SECONDS, src))
				to_chat(user, span_warning("You stop sealing the missile."))
				return
			if(construction_state != MISSILE_STATE_PAYLOAD)
				return
			construction_state = MISSILE_STATE_ARMED
			update_appearance()
			to_chat(user, span_notice("You seal [src]. It's now armed and ready to load."))
			playsound(src, 'sound/machines/click.ogg', 50, TRUE)
			return
		// Unseal an armed missile
		if(construction_state == MISSILE_STATE_ARMED)
			to_chat(user, span_notice("You unseal [src]."))
			construction_state = MISSILE_STATE_PAYLOAD
			update_appearance()
			playsound(src, 'sound/machines/click.ogg', 50, TRUE)
			return
		// Remove tracking circuit
		if(construction_state == MISSILE_STATE_TRACKING)
			to_chat(user, span_notice("You remove [tracking] from [src]."))
			tracking.forceMove(drop_location())
			tracking = null
			construction_state = MISSILE_STATE_WIRED
			update_appearance()
			return
		if(construction_state < MISSILE_STATE_TRACKING)
			to_chat(user, span_warning("[src] has no tracking circuit to remove!"))
		return

	// Crowbar to remove warhead
	if(W.tool_behaviour == TOOL_CROWBAR)
		if(construction_state == MISSILE_STATE_ARMED)
			to_chat(user, span_warning("[src] is sealed! Use a screwdriver to unseal it first."))
			return
		if(construction_state != MISSILE_STATE_PAYLOAD)
			to_chat(user, span_warning("[src] has no warhead to remove!"))
			return
		to_chat(user, span_notice("You pry out [warhead] from [src]."))
		warhead.forceMove(drop_location())
		warhead = null
		construction_state = MISSILE_STATE_TRACKING
		update_appearance()
		return

	return ..()

// Deconstruction
/obj/structure/ship_missile/welder_act(mob/living/user, obj/item/tool)
	if(construction_state >= MISSILE_STATE_PAYLOAD)
		to_chat(user, span_warning("Remove the warhead first - it's dangerous to weld a missile with explosives!"))
		return ITEM_INTERACT_BLOCKING
	to_chat(user, span_notice("You begin cutting apart [src]..."))
	if(!tool.use_tool(src, user, 3 SECONDS, volume = 50))
		return ITEM_INTERACT_BLOCKING
	to_chat(user, span_notice("You cut [src] apart."))
	new /obj/item/stack/sheet/iron(drop_location(), 5)
	if(construction_state >= MISSILE_STATE_WIRED)
		new /obj/item/stack/cable_coil(drop_location(), 5)
	if(tracking)
		tracking.forceMove(drop_location())
		tracking = null
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/// Returns data for the missile launcher to use when firing
/obj/structure/ship_missile/proc/get_fire_data()
	if(construction_state != MISSILE_STATE_ARMED || !warhead)
		return null
	var/list/data = list(
		"effect_type" = warhead.missile_effect_type,
		"payload_type" = warhead.payload_type,
		"damage" = warhead.ship_damage,
		"devastation" = warhead.range_heavy,
		"heavy" = warhead.range_medium,
		"light" = warhead.range_light,
		"flame" = warhead.range_flame,
		"icon_state" = warhead.missile_icon_state,
	)

	// Add chemical warhead data if applicable
	if(istype(warhead, /obj/item/bombcore/missile/chemical))
		var/obj/item/bombcore/missile/chemical/chem_warhead = warhead
		// Copy the reagents for later use
		var/list/datum/reagents/reagent_copies = list()
		for(var/obj/item/container in chem_warhead.beakers)
			if(container.reagents && container.reagents.total_volume > 0)
				var/datum/reagents/copy = new(container.reagents.maximum_volume)
				container.reagents.trans_to(copy, container.reagents.total_volume, no_react = TRUE)
				reagent_copies += copy
		data["chem_reagents"] = reagent_copies
		data["chem_area"] = chem_warhead.affected_area
		data["chem_temp"] = chem_warhead.ignition_temp

	// Add EMP data if applicable
	if(istype(warhead, /obj/item/bombcore/missile/emp))
		var/obj/item/bombcore/missile/emp/emp_warhead = warhead
		data["emp_heavy"] = emp_warhead.emp_heavy
		data["emp_light"] = emp_warhead.emp_light

	return data
