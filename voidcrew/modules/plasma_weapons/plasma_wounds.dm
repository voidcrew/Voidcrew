// Plasma burns: a wound series for plasma bolts.
//
// A subtype of tg's flesh burn, so every burn treatment (ointment, mesh, synthflesh, gauze, the
// debride surgery, sterilizine, the UV penlight) works unchanged. On top of that the wound holds
// molten slag: while slag is in, the burn cannot close, cryo cannot clear it, and a critical limps
// or fumbles. Hot slag keeps burning the limb through tg's own apply_damage until it is cooled or
// cut out. Field picks and the surgery live in plasma_wound_care.dm, the overlay in
// plasma_wound_looks.dm.

/// TRUE when a damage source should roll the plasma burn series instead of tg's burns.
/proc/plasma_burn_source(source)
	return istype(source, /obj/projectile/energy/plasma_bolt)

/// TRUE if the limb carries a critical burn of any kind. Burst C reads this.
/proc/plasma_limb_burned_through(obj/item/bodypart/limb)
	if(!limb)
		return FALSE
	for(var/datum/wound/burn/flesh/burn in limb.wounds)
		if(burn.severity >= WOUND_SEVERITY_CRITICAL)
			return TRUE
	return FALSE

/// TRUE if the limb carries a Plasma Burn-Through that still holds slag: the rifle's burn-through melt.
/proc/plasma_burn_through_ready(obj/item/bodypart/limb)
	var/datum/wound/burn/flesh/plasma/critical/burn_through = limb?.get_wound_type(/datum/wound/burn/flesh/plasma/critical)
	return !!(burn_through && burn_through.slag > 0)

/// The plasma burn typepath for a severity, or null.
/proc/plasma_burn_tier_path(severity)
	switch(severity)
		if(WOUND_SEVERITY_MODERATE)
			return /datum/wound/burn/flesh/plasma/moderate
		if(WOUND_SEVERITY_SEVERE)
			return /datum/wound/burn/flesh/plasma/severe
		if(WOUND_SEVERITY_CRITICAL)
			return /datum/wound/burn/flesh/plasma/critical

// ---------------------------------------------------------------------------------------------
// Pregen data. Static weight 0 keeps the series out of get_corresponding_wound_type() (fire, lava,
// smites, admin wound verbs); the real roll only happens through get_weight() with a plasma source.

/datum/wound_pregen_data/flesh_burn/plasma
	abstract = TRUE
	weight = 0
	overpower_wounds_of_even_severity = TRUE

/datum/wound_pregen_data/flesh_burn/plasma/get_weight(obj/item/bodypart/limb, woundtype, damage, attack_direction, damage_source)
	return plasma_burn_source(damage_source) ? WOUND_DEFAULT_WEIGHT : 0

/datum/wound_pregen_data/flesh_burn/plasma/get_threshold_for(obj/item/bodypart/part, attack_direction, damage_source)
	return plasma_burn_source(damage_source) ? threshold_minimum : INFINITY

/datum/wound_pregen_data/flesh_burn/plasma/moderate
	abstract = FALSE
	wound_path_to_generate = /datum/wound/burn/flesh/plasma/moderate
	threshold_minimum = 40

/datum/wound_pregen_data/flesh_burn/plasma/severe
	abstract = FALSE
	wound_path_to_generate = /datum/wound/burn/flesh/plasma/severe
	threshold_minimum = 80

/datum/wound_pregen_data/flesh_burn/plasma/critical
	abstract = FALSE
	wound_path_to_generate = /datum/wound/burn/flesh/plasma/critical
	threshold_minimum = 140

// ---------------------------------------------------------------------------------------------
// Status effects

/datum/status_effect/wound/burn/flesh/plasma/moderate
	id = "slagspatter"

/datum/status_effect/wound/burn/flesh/plasma/severe
	id = "slagembedded"

/datum/status_effect/wound/burn/flesh/plasma/critical
	id = "burnthrough"

// ---------------------------------------------------------------------------------------------
// The wound

/datum/wound/burn/flesh/plasma
	name = "Plasma Burns"
	undiagnosed_name = "Plasma Burns"
	default_scar_file = PLASMA_SCAR_FILE
	// The bolt's own hit and burn-through sounds carry the wound; no tg sizzle on top
	sound_effect = null
	// The slag tools (hemostat, wirecutters, scalpel) are gated in plasma_wound_care.dm's item_can_treat().

	/// Slag still in the wound
	var/slag = 0
	/// Seconds of heat left
	var/heat = 0
	/// Healing held back while slag is in
	var/stored_healing = 0

	/// Burn a second while hot
	var/cook_rate = 0
	/// Moderate flecks fall off by themselves once cool
	var/sheds = FALSE
	/// A slag bead drops when the last slag comes out
	var/drops_bead = FALSE
	/// Set when this wound replaced a slagged one because of a non-plasma burn: it keeps the old slag and heat instead of fresh ones
	var/carried_over = FALSE
	/// Set once the burn has landed; re-attaching a severed limb applies it again and must not heat it up or dose the blood
	var/landed = FALSE
	/// tg's burn of the same tier; its short treatment text is used once the slag is out
	var/datum/wound/burn/flesh/tg_tier_path = /datum/wound/burn/flesh/moderate

	/// Examine text while the slag glows
	var/examine_hot = ""
	/// Examine text once the slag has set
	var/examine_set = ""
	/// Examine text with the slag out
	var/examine_raw = ""
	/// Scanner short treatment text while slag is in
	var/slag_treat_text_short = ""

/datum/wound/burn/flesh/plasma/moderate
	name = "Slag Spatter Burns"
	desc = "Patient has flecks of plasma slag stuck to scalded skin, weakening limb integrity."
	treat_text = "Cool the area. The flecks will shed, or can be picked off. Apply ointment or regenerative mesh."
	treat_text_short = "Cool, then apply ointment or regenerative mesh."
	slag_treat_text_short = "Cool, then apply ointment or regenerative mesh."
	examine_desc = "is spattered with glowing purple flecks"
	examine_hot = "is spattered with glowing purple flecks"
	examine_set = "is scalded and crusted with black flecks"
	examine_raw = "is scalded and blistering"
	occur_text = "spits and blisters as molten flecks stick to it"
	severity = WOUND_SEVERITY_MODERATE
	damage_multiplier_penalty = 1.1
	series_threshold_penalty = 30
	status_effect_type = /datum/status_effect/wound/burn/flesh/plasma/moderate
	flesh_damage = 5
	scar_keyword = "plasmamoderate"
	tg_tier_path = /datum/wound/burn/flesh/moderate

	slag = PLASMA_WOUND_SLAG_MODERATE
	heat = PLASMA_WOUND_HEAT_MODERATE
	sheds = TRUE

	simple_desc = "Patient's skin is scalded and spattered with plasma slag!"
	simple_treat_text = "<b>Water</b> will cool it. <b>Ointment or regenerative mesh</b> will speed up recovery."
	homemade_treat_text = "The flecks fall off by themselves once cool. <b>Healthy tea</b> will speed up recovery."

/datum/wound/burn/flesh/plasma/severe
	name = "Embedded Slag Burns"
	desc = "Patient has plasma slag fused into deep burns. The burns will not close while it remains, and there is serious risk of infection."
	treat_text = "Cool the slag. Excise it with a hemostat, in the field or in surgery. Then treat as third degree burns: regenerative mesh or Synthflesh, disinfect, and dress."
	treat_text_short = "Cool the slag, excise it with a hemostat, then treat the burns."
	slag_treat_text_short = "Cool the slag, excise it with a hemostat, then treat the burns."
	examine_desc = "is studded with glowing slag, the flesh around it still cooking"
	examine_hot = "is studded with glowing slag, the flesh around it still cooking"
	examine_set = "is charred, with beads of black glass fused into the flesh"
	examine_raw = "is charred and pitted with raw sockets"
	occur_text = "sizzles as molten slag sinks into the flesh"
	severity = WOUND_SEVERITY_SEVERE
	damage_multiplier_penalty = 1.2
	series_threshold_penalty = 40
	status_effect_type = /datum/status_effect/wound/burn/flesh/plasma/severe
	treatable_by = list(/obj/item/flashlight/pen/paramedic, /obj/item/stack/medical/ointment, /obj/item/stack/medical/mesh)
	infestation_rate = 0.07
	flesh_damage = 12.5
	scar_keyword = "plasmasevere"
	tg_tier_path = /datum/wound/burn/flesh/severe

	slag = PLASMA_WOUND_SLAG_SEVERE
	heat = PLASMA_WOUND_HEAT_SEVERE
	cook_rate = PLASMA_WOUND_COOK_SEVERE
	drops_bead = TRUE

	simple_desc = "Patient has plasma slag burned into the flesh, and it won't heal until that comes out!!"
	simple_treat_text = "<b>Cool it with water</b>, then have the slag <b>picked out with a hemostat</b>. After that, <b>ointment or regenerative mesh</b>."
	homemade_treat_text = "A <b>fire extinguisher</b> cools it as well as anything. <b>Wirecutters</b> will do if there is no hemostat. It will hurt."

/datum/wound/burn/flesh/plasma/critical
	name = "Plasma Burn-Through"
	desc = "Patient's limb is burned through, with plasma slag fused to muscle and bone. Plasma may have entered the blood. Negligible limb integrity."
	treat_text = "Cool the slag immediately. Excise it with a hemostat, in the field or in surgery. Check the blood for plasma. Then treat as catastrophic burns."
	treat_text_short = "Cool the slag, excise it with a hemostat, check for plasma in the blood, then treat the burns."
	slag_treat_text_short = "Cool the slag, excise it with a hemostat, check for plasma in the blood, then treat the burns."
	examine_desc = "is burned clean through, the hole ringed with glowing slag"
	examine_hot = "is burned clean through, the hole ringed with glowing slag"
	examine_set = "is burned clean through, the hole lined with black glass"
	examine_raw = "has a charred hole burned clean through it"
	occur_text = "burns straight through, slag fusing to the bone"
	severity = WOUND_SEVERITY_CRITICAL
	damage_multiplier_penalty = 1.3
	threshold_penalty = 25
	status_effect_type = /datum/status_effect/wound/burn/flesh/plasma/critical
	treatable_by = list(/obj/item/flashlight/pen/paramedic, /obj/item/stack/medical/ointment, /obj/item/stack/medical/mesh)
	infestation_rate = 0.075
	flesh_damage = 20
	scar_keyword = "plasmacritical"
	tg_tier_path = /datum/wound/burn/flesh/critical
	// Critical with slag in: a leg limps, an arm fumbles. Cleared in update_inefficiencies() once the slag is out.
	limp_slowdown = PLASMA_WOUND_LIMP_SLOWDOWN
	limp_chance = PLASMA_WOUND_LIMP_CHANCE
	interaction_efficiency_penalty = PLASMA_WOUND_FUMBLE

	slag = PLASMA_WOUND_SLAG_CRITICAL
	heat = PLASMA_WOUND_HEAT_CRITICAL
	cook_rate = PLASMA_WOUND_COOK_CRITICAL
	drops_bead = TRUE

	simple_desc = "Patient has a hole burned through the limb, full of plasma slag!!!"
	simple_treat_text = "<b>Cool it with water now</b>. Get the slag <b>cut out</b> and get <b>professional care</b> before infection sets in."
	homemade_treat_text = "A <b>fire extinguisher</b> or a <b>shower</b> will cool it. <b>Wirecutters</b> will do if there is no hemostat. Keep the patient out of fights."

// ---------------------------------------------------------------------------------------------
// API

/// Takes slag out, clamped at zero. Returns the amount removed. Only the call that empties the wound
/// clears it (one bead, healing released, limp cleared), so two picks landing at once can't double up.
/datum/wound/burn/flesh/plasma/proc/remove_slag(amount, mob/user)
	if(slag <= 0 || amount <= 0)
		return 0
	var/removed = min(amount, slag)
	slag = max(round(slag - removed, 0.01), 0)
	if(slag <= 0)
		slag_cleared(user)
	return removed

/// Cools the wound at once. Returns TRUE if it was hot.
/datum/wound/burn/flesh/plasma/proc/quench(silent = FALSE)
	if(heat <= 0)
		return FALSE
	heat = 0
	if(!silent && victim && limb)
		victim.visible_message(
			span_notice("The slag in [victim]'s [limb.plaintext_zone] hisses and goes dark."),
			span_notice("The slag in your [limb.plaintext_zone] hisses and goes dark."),
			vision_distance = COMBAT_MESSAGE_RANGE,
		)
		playsound(victim, PLASMA_SOUND_QUENCH, 25, TRUE, falloff_exponent = SOUND_FALLOFF_EXPONENT + 2, ignore_walls = FALSE)
		var/turf/victim_turf = get_turf(victim)
		if(victim_turf)
			new /obj/effect/particle_effect/steam(victim_turf)
	plasma_state_changed()
	return TRUE

/// Returns "hot", "set" or "raw".
/datum/wound/burn/flesh/plasma/proc/look_state()
	if(slag <= 0)
		return "raw"
	if(heat > 0)
		return "hot"
	return "set"

// ---------------------------------------------------------------------------------------------
// Internals

/// Text and look follow the wound's state.
/datum/wound/burn/flesh/plasma/proc/plasma_state_changed()
	if(QDELETED(src))
		return
	update_descriptions()
	update_look()

/// The last slag is out: the burn can close, the limp ends, healing given early is released.
/datum/wound/burn/flesh/plasma/proc/slag_cleared(mob/user)
	slag = 0
	heat = 0
	if(stored_healing > 0)
		flesh_healing += stored_healing
		stored_healing = 0
	if(limb)
		update_inefficiencies()
	if(drops_bead)
		var/atom/drop_at = victim ? victim.drop_location() : limb?.drop_location()
		if(drop_at)
			new /obj/item/plasma_slag(drop_at)
	plasma_state_changed()

/// Moves healing the burn can't use yet into storage, capped at the flesh damage.
/datum/wound/burn/flesh/plasma/proc/bank_healing()
	if(flesh_healing <= 0)
		return
	stored_healing = min(stored_healing + flesh_healing, flesh_damage)
	flesh_healing = 0

/// Tops the blood up to PLASMA_WOUND_BLOOD_PLASMA units of plasma; never adds past it.
/datum/wound/burn/flesh/plasma/proc/top_up_blood_plasma()
	if(!victim?.reagents)
		return
	var/current = victim.reagents.get_reagent_amount(/datum/reagent/toxin/plasma)
	if(current < PLASMA_WOUND_BLOOD_PLASMA)
		victim.reagents.add_reagent(/datum/reagent/toxin/plasma, PLASMA_WOUND_BLOOD_PLASMA - current)

/// How fast the slag cools where the victim is: 0 in a fire, faster in the cold.
/datum/wound/burn/flesh/plasma/proc/cooling_factor()
	// The species' own limits, so a body that runs hot (ethereals) or cold still cools at its normal temperature
	var/heat_limit = BODYTEMP_HEAT_DAMAGE_LIMIT
	var/cold_limit = BODYTEMP_COLD_DAMAGE_LIMIT
	var/datum/species/species = ishuman(victim) ? victim.dna?.species : null
	if(species)
		heat_limit = species.bodytemp_heat_damage_limit
		cold_limit = species.bodytemp_cold_damage_limit
	if(victim.on_fire || victim.bodytemperature > heat_limit)
		return 0
	if(victim.bodytemperature < cold_limit)
		return PLASMA_WOUND_COLD_BODY_FACTOR
	var/datum/gas_mixture/air = victim.loc?.return_air()
	if(air && air.return_temperature() < T0C && air.return_pressure() >= PLASMA_WOUND_COLD_AIR_PRESSURE)
		return PLASMA_WOUND_COLD_AIR_FACTOR
	return 1

/// Wet skin quenches; otherwise hot slag cooks the limb (if cook is TRUE) and cools a little.
/datum/wound/burn/flesh/plasma/proc/process_heat(seconds_per_tick, cook = TRUE)
	if(heat <= 0 || slag <= 0)
		return
	if(victim.has_status_effect(/datum/status_effect/fire_handler/wet_stacks))
		quench()
		return
	if(cook && cook_rate > 0)
		// CANT_WOUND: cooking never rolls or upgrades a wound, and attacking_item is null so the bolt's melt check ignores it.
		victim.apply_damage(cook_rate * seconds_per_tick, BURN, limb, wound_bonus = CANT_WOUND, wound_clothing = FALSE)
		if(QDELETED(src) || !victim || !limb)
			return
		if(prob(8))
			to_chat(victim, span_danger("The slag in your [limb.plaintext_zone] is still cooking!"))
	heat = max(heat - (seconds_per_tick * cooling_factor()), 0)
	if(heat <= 0)
		to_chat(victim, span_notice("The slag in your [limb.plaintext_zone] stops glowing."))
		plasma_state_changed()

/// Moderate flecks fall off once cool.
/datum/wound/burn/flesh/plasma/proc/process_shedding(seconds_per_tick)
	if(!sheds || heat > 0 || slag <= 0)
		return
	remove_slag(PLASMA_WOUND_SHED_RATE * seconds_per_tick)
	if(slag <= 0 && victim && limb)
		to_chat(victim, span_notice("The flecks on your [limb.plaintext_zone] flake away."))

// ---------------------------------------------------------------------------------------------
// tg hooks

/datum/wound/burn/flesh/plasma/wound_injury(datum/wound/old_wound = null, attack_direction = null)
	. = ..()
	if(landed && !old_wound)
		// The limb this burn is on was put back on: it keeps its slag and heat as they were
		if(limb)
			update_inefficiencies()
		plasma_state_changed()
		return
	landed = TRUE
	var/datum/wound/burn/flesh/plasma/old_plasma = istype(old_wound, /datum/wound/burn/flesh/plasma) ? old_wound : null
	if(carried_over && old_plasma)
		// A fire or laser burn replaced slagged plasma: keep what was there, add nothing.
		slag = old_plasma.slag
		heat = old_plasma.heat
	else
		heat = initial(heat)
		if(old_plasma)
			slag = max(slag, old_plasma.slag)
	if(old_plasma)
		infestation = old_plasma.infestation
		sanitization = old_plasma.sanitization
	if(!carried_over && severity >= WOUND_SEVERITY_CRITICAL && (!old_wound || old_wound.severity < severity))
		top_up_blood_plasma()
	if(limb)
		update_inefficiencies()
	plasma_state_changed()

/datum/wound/burn/flesh/plasma/replace_wound(datum/wound/new_wound, smited = FALSE, attack_direction = null)
	// A bigger tg burn over slag (a slagged limb held in a fire) becomes the plasma burn of that tier, so slag is never burned away.
	if(slag > 0 && new_wound && (new_wound.type in list(/datum/wound/burn/flesh/moderate, /datum/wound/burn/flesh/severe, /datum/wound/burn/flesh/critical)))
		var/plasma_path = plasma_burn_tier_path(new_wound.severity)
		if(plasma_path)
			var/datum/wound/burn/flesh/plasma/swapped = new plasma_path
			swapped.carried_over = TRUE
			qdel(new_wound)
			new_wound = swapped
	return ..(new_wound, smited, attack_direction)

// tg's bodypart receive_damage() passes the damage source in this proc's attack_direction slot
// (_bodyparts.dm: iter_wound.receive_damage(wounding_type, wounding_dmg, wound_bonus, damage_source)),
// so both slots are read. A fresh plasma bolt re-melts slag already in the limb.
/datum/wound/burn/flesh/plasma/receive_damage(wounding_type, wounding_dmg, wound_bonus, attack_direction, damage_source)
	. = ..()
	if(slag <= 0)
		return
	if(!plasma_burn_source(attack_direction) && !plasma_burn_source(damage_source))
		return
	heat = initial(heat)
	// Re-times the glow from full heat, or lights it again if it had cooled
	plasma_state_changed()

/datum/wound/burn/flesh/plasma/handle_process(seconds_per_tick, times_fired)
	if(!victim || HAS_TRAIT(victim, TRAIT_STASIS))
		return ..()
	var/held_damage = flesh_damage
	var/held_infestation = infestation
	// Bank healing before tg's tick so its heal step has nothing to spend while slag is in.
	if(slag > 0)
		bank_healing()
	. = ..()
	if(QDELETED(src) || !victim || !limb)
		return
	// The burn can't close while slag is in: undo any healing tg's tick did, keep what reagents added for later.
	if(slag > 0)
		flesh_damage = max(flesh_damage, held_damage)
		bank_healing()
	// Hot slag is sterile.
	if(heat > 0)
		infestation = min(infestation, held_infestation)
	process_heat(seconds_per_tick)
	if(QDELETED(src) || !victim || !limb)
		return
	process_shedding(seconds_per_tick)

// On a stasis bed tg's tick doesn't run: the slag cools with no cooking, and stored healing stays stored.
/datum/wound/burn/flesh/plasma/on_stasis(seconds_per_tick, times_fired)
	var/held_damage = flesh_damage
	if(slag > 0)
		bank_healing()
	. = ..()
	if(QDELETED(src) || !victim || !limb)
		return
	if(slag > 0)
		flesh_damage = max(flesh_damage, held_damage)
		bank_healing()
	process_heat(seconds_per_tick, cook = FALSE)
	process_shedding(seconds_per_tick)

/datum/wound/burn/flesh/plasma/on_xadone(power)
	// Cryoxadone works on a frozen body; pyroxadone on a hot one doesn't cool slag.
	if(victim && victim.bodytemperature < T0C)
		quench()
	return ..()

/datum/wound/burn/flesh/plasma/handle_xadone_progress()
	if(slag > 0)
		cryo_progress = min(cryo_progress || 0, get_xadone_progress_to_qdel())
		return
	return ..()

/datum/wound/burn/flesh/plasma/can_be_ointmented_or_meshed()
	if(slag <= 0)
		return ..()
	if(infestation > 0 && sanitization < infestation)
		return TRUE
	return flesh_damage > 0 && (flesh_healing + stored_healing) < flesh_damage

/datum/wound/burn/flesh/plasma/update_inefficiencies(replaced_or_replacing = FALSE)
	. = ..()
	if(!limb)
		return
	if(slag > 0 && (limb.body_zone in GLOB.arm_zones))
		return
	// Fumble only applies to an arm with slag in.
	if(interaction_efficiency_penalty != 1)
		set_interaction_efficiency_penalty(1)
	if(slag > 0)
		return
	if(!limp_slowdown && !limp_chance)
		return
	limp_slowdown = 0
	limp_chance = 0
	// The limp effect only re-reads wounds on gain and loss signals.
	var/datum/status_effect/limp/limp = victim?.has_status_effect(/datum/status_effect/limp)
	limp?.update_limp(victim)

/datum/wound/burn/flesh/plasma/set_disabling(new_value)
	. = ..()
	update_descriptions()

/datum/wound/burn/flesh/plasma/update_descriptions()
	switch(look_state())
		if("hot")
			examine_desc = examine_hot
		if("set")
			examine_desc = examine_set
		else
			examine_desc = examine_raw
	if(disabling && strikes_to_lose_limb <= 0)
		// tg's sepsis text, except cryo can't clear it while slag is in
		if(slag > 0)
			treat_text_short = "Amputate or augment limb immediately, or excise the slag and place the patient into cryogenics."
		return
	if(slag > 0)
		treat_text_short = slag_treat_text_short
	else
		var/datum/wound/burn/flesh/tg_tier = tg_tier_path
		treat_text_short = initial(tg_tier.treat_text_short)

/datum/wound/burn/flesh/plasma/get_scanner_description(mob/user)
	. = ..()
	if(slag <= 0)
		return
	// Cryo can't clear sepsis while slag is in
	. = replacetext(., "or place the patient in a cryotube.", "or excise the slag and place the patient in a cryotube.")
	var/foreign = "Foreign matter: plasma slag, [heat > 0 ? "molten" : "set"].\n"
	var/div_open = "<div class='ml-3'>"
	var/div_at = findtext(., div_open)
	if(div_at)
		var/insert_at = div_at + length(div_open)
		. = copytext(., 1, insert_at) + foreign + copytext(., insert_at)
	else
		. += "[div_open][foreign]</div>"

/datum/wound/burn/flesh/plasma/get_limb_examine_description()
	if(severity >= WOUND_SEVERITY_CRITICAL)
		return span_warning("The flesh on this limb is burned through and crusted with black glass.")
	return span_warning("The flesh on this limb is charred and studded with black glass.")

/datum/wound/burn/flesh/plasma/get_scar_file(obj/item/bodypart/scarred_limb, add_to_scars)
	if(scarred_limb.biological_state & BIO_FLESH)
		return PLASMA_SCAR_FILE
	return ..()
