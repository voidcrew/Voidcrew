/**
 * # Street chrome (Tier 1)
 *
 * The cheap shelf: job-lube and fun utility, credits only. Every ware here
 * rides /obj/item/organ/cyberimp/cyberware (chest-default generic base)
 * except Nightshade, which lives with the other optics in the eyes base.
 * The two toolkit-arm T1s (Rockjaw, Fixer's Fingers) are in
 * ware_arm_utility.dm; the T2 shelf is ware_pro_utility.dm.
 */

/// Flat damage Scrapper's Knuckles adds to an unarmed punch against mobs.
#define CYBERWARE_SCRAPPER_PUNCH_BONUS 4
/// How long the Gecko Grips chasm-lip catch takes to re-set after saving you.
#define CYBERWARE_GECKO_CATCH_COOLDOWN (30 SECONDS)
/// Disgust scrubbed from the Gastro Reactor's bearer per second, the
/// "food poisoning immunity": you never build up to retching.
#define CYBERWARE_GASTRO_DISGUST_PURGE 3
/// Perceived-quality bonus the Gastro Reactor adds to anything you eat.
/// +6 lifts gross/rotten (-5 tier) food back above "meh" so it goes down
/// without complaint; species-toxic food still refuses to become dinner.
#define CYBERWARE_GASTRO_QUALITY_BONUS 6
/// Biggest item the Cargo Cavity will swallow.
#define CYBERWARE_CAVITY_MAX_WCLASS WEIGHT_CLASS_SMALL

// ---- 1. Chromatic Dermis ----------------------------------------------

/**
 * The ink patterns, in Cradle order. `size` is the outline thickness the
 * pattern draws at and `idle` the alpha it rests at, so picking a pattern is
 * a real look change rather than a word in your examine text: hex weave is a
 * tight bright line, starburst a wide soft halo, bar code a dim trace that
 * only shows when something sets it off.
 */
GLOBAL_LIST_INIT(cyberware_ink_patterns, list(
	"circuit traces" = list("size" = 1, "idle" = 150, "blurb" = "A clean single trace. The parlor default."),
	"serpent coil" = list("size" = 2, "idle" = 130, "blurb" = "Heavier line, wound down the limbs."),
	"hex weave" = list("size" = 1, "idle" = 200, "blurb" = "Tight and bright. Nobody misses you."),
	"starburst" = list("size" = 3, "idle" = 95, "blurb" = "A wide soft halo instead of a line."),
	"bar code" = list("size" = 1, "idle" = 70, "blurb" = "Nearly dark until something sets it off."),
))

/// The parlor's stock ink colours. Free text is deliberately not on offer.
/// These are the pigments Splice keeps in the drawer.
GLOBAL_LIST_INIT(cyberware_ink_palette, list(
	"Parlor Cyan" = "#4dd8e6",
	"Splice Magenta" = "#ff2079",
	"Hazard Amber" = "#ffb347",
	"Ripper Green" = "#aaff3c",
	"Arterial Red" = "#e6394d",
	"Deep Violet" = "#9b5cff",
	"Ion Blue" = "#3d7bff",
	"Cold White" = "#d8f4ff",
))

/**
 * # Chromatic Dermis (T1, chest, ink slot, load 0)
 *
 * Emissive circuit-tattoos under the skin: pure flex, everyone's first
 * install. Rendered as a coloured outline on the bearer, re-keyed for colour
 * and pattern at the Chrome Cradle.
 *
 * It is also the framework's shared tell. Anything on the body that does
 * something worth looking at, a fist landing, a tool folding out of a
 * forearm, the Cargo Cavity swallowing something, the grips clamping, the
 * bladder taking over your breathing. Calls cyberware_ink_pulse() on its
 * bearer, and the ink answers. Chrome you can't see from outside stops being
 * invisible the moment you also wear this.
 */
/obj/item/organ/cyberimp/cyberware/chromatic_dermis
	name = "\improper Chromatic Dermis ink suite"
	desc = "Programmable tattoo ink and the spider-legged injector that lays it under the skin. The traces light up whenever the rest of your chrome does something: a punch landing, a tool folding out, the air bladder kicking in. Colour and pattern are set at a Chrome Cradle."
	icon_state = "chromatic_dermis"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_INK
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 0
	tier = CYBERWARE_TIER_1
	/// Glow colour, "#rrggbb". Re-keyed at the Cradle; defaults to parlor cyan.
	var/tattoo_color = "#4dd8e6"
	/// Pattern name: a key into GLOB.cyberware_ink_patterns, which is what
	/// decides the outline's thickness and resting brightness.
	var/tattoo_pattern = "circuit traces"
	/// Filter key on the bearer. Keyed to us so two-dermis nonsense can't collide.
	var/filter_name = "chromatic_dermis"
	/// The outline alpha the ink idles at, recomputed each life tick from
	/// nutrition and failure state. Cached so we only touch the filter on change.
	var/current_alpha = -1
	/// How many pulses the ink has actually run, and what the last one's
	/// strength was. A pulse is a client-side animation with no state to read
	/// back, so these are the only handle anything server-side has on whether
	/// the ink fired: VV, and the conformance test that keeps every ware's
	/// activation wired to cyberware_ink_pulse().
	var/pulse_count = 0
	var/last_pulse_strength = 0

/obj/item/organ/cyberimp/cyberware/chromatic_dermis/examine(mob/user)
	. = ..()
	. += span_notice("The ink is keyed to <font color='[tattoo_color]'><b>this colour</b></font> in a [tattoo_pattern] pattern.")

/obj/item/organ/cyberimp/cyberware/chromatic_dermis/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	current_alpha = -1
	apply_ink_filter()
	settle_glow()
	RegisterSignal(organ_owner, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_owner_damaged))
	RegisterSignal(organ_owner, COMSIG_MOB_ABILITY_STARTED, PROC_REF(on_ability_started))
	// Generic combat: any swing lights the ink, with or without chrome fists.
	// Ware-specific beats come in through cyberware_ink_pulse() instead.
	RegisterSignal(organ_owner, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_unarmed_attack))
	RegisterSignal(organ_owner, COMSIG_MOB_ITEM_ATTACK, PROC_REF(on_item_attack))

/obj/item/organ/cyberimp/cyberware/chromatic_dermis/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, list(
		COMSIG_MOB_APPLY_DAMAGE,
		COMSIG_MOB_ABILITY_STARTED,
		COMSIG_LIVING_UNARMED_ATTACK,
		COMSIG_MOB_ITEM_ATTACK,
	))
	organ_owner.remove_filter(filter_name)
	current_alpha = -1

/// The tattoo colour with an alpha byte appended, for the outline filter.
/obj/item/organ/cyberimp/cyberware/chromatic_dermis/proc/glow_color(alpha)
	return "[tattoo_color][num2hex(clamp(alpha, 0, 255), 2)]"

/// This pattern's entry, or the default's if someone has hand-set nonsense.
/obj/item/organ/cyberimp/cyberware/chromatic_dermis/proc/pattern_data()
	RETURN_TYPE(/list)
	return GLOB.cyberware_ink_patterns[tattoo_pattern] || GLOB.cyberware_ink_patterns["circuit traces"]

/**
 * (Re)hangs the outline filter at the current pattern's thickness. Filter
 * size can't be animated between patterns cleanly, so a pattern change tears
 * the filter down and builds a new one; colour and alpha still animate.
 */
/obj/item/organ/cyberimp/cyberware/chromatic_dermis/proc/apply_ink_filter()
	if(!owner)
		return
	var/list/pattern = pattern_data()
	owner.remove_filter(filter_name)
	owner.add_filter(filter_name, 2, outline_filter(pattern["size"], glow_color(max(current_alpha, 0))))

/**
 * Recomputes the idle glow: browned-out/EMP'd ink goes dark, a starving
 * bearer's ink gutters low, everyone else gets their pattern's full shine.
 * Called every life tick: cheap, and only touches the filter on change.
 */
/obj/item/organ/cyberimp/cyberware/chromatic_dermis/proc/settle_glow()
	if(!owner)
		return
	var/list/pattern = pattern_data()
	var/target_alpha = pattern["idle"]
	if(organ_flags & ORGAN_FAILING)
		target_alpha = 0
	else if(owner.nutrition < NUTRITION_LEVEL_HUNGRY)
		target_alpha = round(target_alpha * 0.3)
	if(target_alpha == current_alpha)
		return
	current_alpha = target_alpha
	var/filter = owner.get_filter(filter_name)
	if(filter)
		animate(filter, color = glow_color(target_alpha), time = 1 SECONDS)

/obj/item/organ/cyberimp/cyberware/chromatic_dermis/on_life(seconds_per_tick, times_fired)
	. = ..()
	settle_glow()

/**
 * THE thing the ink is for: light up. Called straight by the dermis' own
 * signal handlers and, from everywhere else on the body, through
 * cyberware_ink_pulse(). Three shapes, all easing back to whatever idle the
 * bearer's pattern and blood sugar leave them at.
 */
/obj/item/organ/cyberimp/cyberware/chromatic_dermis/proc/pulse(strength = CYBERWARE_INK_SOFT)
	if((organ_flags & ORGAN_FAILING) || !owner)
		return
	var/filter = owner.get_filter(filter_name)
	if(!filter)
		return
	pulse_count++
	last_pulse_strength = strength
	var/idle = max(current_alpha, 0)
	switch(strength)
		if(CYBERWARE_INK_FLARE)
			animate(filter, color = glow_color(255), time = 0.1 SECONDS)
			animate(color = glow_color(idle), time = 0.9 SECONDS)
		if(CYBERWARE_INK_HARD)
			animate(filter, color = glow_color(230), time = 0.15 SECONDS)
			animate(color = glow_color(60), time = 0.15 SECONDS)
			animate(color = glow_color(230), time = 0.15 SECONDS)
			animate(color = glow_color(idle), time = 0.4 SECONDS)
		else
			animate(filter, color = glow_color(min(idle + 90, 255)), time = 0.2 SECONDS)
			animate(color = glow_color(idle), time = 0.6 SECONDS)

/// Signal proc for [COMSIG_MOB_APPLY_DAMAGE]: the ink flares hot when the
/// bearer takes a real hit, then eases back to idle.
/obj/item/organ/cyberimp/cyberware/chromatic_dermis/proc/on_owner_damaged(datum/source, damage, damagetype, def_zone)
	SIGNAL_HANDLER
	if(damage < 1)
		return
	pulse(CYBERWARE_INK_FLARE)

/// Signal proc for [COMSIG_MOB_ABILITY_STARTED]: a double-strobe whenever any
/// chrome cooldown ability fires. Other ability families (spells, mob
/// abilities) don't light the ink, chrome answers chrome.
/obj/item/organ/cyberimp/cyberware/chromatic_dermis/proc/on_ability_started(mob/source, datum/action/cooldown/ability)
	SIGNAL_HANDLER
	if(!istype(ability, /datum/action/cooldown/cyberware))
		return
	pulse(CYBERWARE_INK_HARD)

/// Signal proc for [COMSIG_LIVING_UNARMED_ATTACK]: fists light the ink,
/// chrome ones or not. Only real swings. Help-intent pats aren't a beat.
/obj/item/organ/cyberimp/cyberware/chromatic_dermis/proc/on_unarmed_attack(mob/living/source, atom/target, proximity, list/modifiers)
	SIGNAL_HANDLER
	if(!proximity || !source.combat_mode)
		return
	pulse(CYBERWARE_INK_HARD)

/// Signal proc for [COMSIG_MOB_ITEM_ATTACK]: swinging something reads softer
/// than throwing a punch, but it still reads.
/obj/item/organ/cyberimp/cyberware/chromatic_dermis/proc/on_item_attack(mob/source, mob/target, mob/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	pulse(CYBERWARE_INK_SOFT)

/**
 * The Cradle's ink panel hook: one colour and one pattern, both applied the
 * moment they're picked. Driven from ui_act rather than a blocking prompt, so
 * the console shows the swatch grid and the patient watches themselves change
 * on the mannequin. Returns TRUE when something actually changed.
 */
/obj/item/organ/cyberimp/cyberware/chromatic_dermis/proc/set_ink(mob/living/carbon/user, new_color, new_pattern)
	if(user != owner)
		return FALSE
	. = FALSE
	if(new_pattern && (new_pattern in GLOB.cyberware_ink_patterns) && new_pattern != tattoo_pattern)
		tattoo_pattern = new_pattern
		// A new pattern is a new outline thickness: rebuild, then re-settle so
		// the idle alpha follows the pattern rather than the old one's.
		current_alpha = -1
		apply_ink_filter()
		settle_glow()
		. = TRUE
	if(new_color && (new_color in GLOB.cyberware_ink_palette) && GLOB.cyberware_ink_palette[new_color] != tattoo_color)
		tattoo_color = GLOB.cyberware_ink_palette[new_color]
		. = TRUE
	if(!.)
		return FALSE
	pulse(CYBERWARE_INK_FLARE)
	user.balloon_alert(user, "ink re-keyed")
	playsound(user, 'sound/machines/terminal/terminal_processing.ogg', 25, TRUE)
	return TRUE

// ---- 2. Nightshade Optics ---------------------------------------------

/**
 * # Nightshade Optics (T1, eyes, load 1)
 *
 * Darkness vision with none of the thermal line's flash weakness: the colour
 * cutoffs light the dark through the standard eye sight-update chain and
 * flash_protect stays at the robotic default. Still no SEE_MOBS, seeing
 * through walls is the thermal line's trade, not ours.
 *
 * What the Nightshade does instead is TAG. Bodies inside its range get a soft
 * green bloom drawn over them, above the lighting plane and visible to nobody
 * but the wearer, so a room full of crates and a room full of people stop
 * looking the same in the dark. The
 * tags are client-side images parented to their target, so they follow
 * without any per-tick bookkeeping; only membership is re-swept, on the
 * wearer's own movement plus a life-tick backstop.
 *
 * The chrome read comes with the base, at street resolution: these count the
 * chrome in a body and read its neural load, but can't name a single piece.
 */
/obj/item/organ/eyes/robotic/cyberware/nightshade
	name = "\improper Nightshade optics"
	desc = "Matte black eyes that render a dark room in green. Living bodies in range pick up a soft glow only you can see, so an unlit corridor isn't cover any more. They aren't thermals, so a flashbang hits you no harder than it would normal eyes. The diagnostic bus is the stock one: it counts how much chrome someone is carrying, but can't name any of it."
	icon_state = "nightshade"
	eye_color_left = "#1d3b2a"
	eye_color_right = "#1d3b2a"
	iris_overlay = null
	// Downshift red so darkness reads as a cold botanical green. Pushed well
	// past the roster's first pass. The whole selling point is that an
	// unlit room is workable, not merely navigable.
	color_cutoffs = list(15, 50, 30)
	// Raises the floor on how dark a tile is allowed to render for us at all.
	lighting_cutoff = LIGHTING_CUTOFF_MEDIUM
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	chrome_scan_resolution = CYBERWARE_SCAN_SILHOUETTE
	/// Bodies we're currently tagging, associated to the image doing it.
	var/list/tagged = list()
	/// Earliest world.time the next membership sweep may run.
	var/next_sweep = 0

/obj/item/organ/eyes/robotic/cyberware/nightshade/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_owner_moved))
	RegisterSignal(organ_owner, COMSIG_MOB_LOGIN, PROC_REF(on_owner_login))
	sweep_tags(force = TRUE)

/obj/item/organ/eyes/robotic/cyberware/nightshade/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	UnregisterSignal(organ_owner, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_LOGIN))
	clear_tags()
	return ..()

/obj/item/organ/eyes/robotic/cyberware/nightshade/Destroy()
	clear_tags()
	return ..()

/obj/item/organ/eyes/robotic/cyberware/nightshade/on_life(seconds_per_tick, times_fired)
	. = ..()
	// Backstop for bodies that walked into range while we stood still.
	sweep_tags()

/// Signal proc for [COMSIG_MOVABLE_MOVED]: our view changed, so the set of
/// bodies in it did too.
/obj/item/organ/eyes/robotic/cyberware/nightshade/proc/on_owner_moved(datum/source)
	SIGNAL_HANDLER
	sweep_tags()

/// Signal proc for [COMSIG_MOB_LOGIN]: a fresh client has an empty image
/// list, so everything we were showing has to be handed over again.
/obj/item/organ/eyes/robotic/cyberware/nightshade/proc/on_owner_login(datum/source)
	SIGNAL_HANDLER
	clear_tags()
	sweep_tags(force = TRUE)

/**
 * Re-derives which bodies we're tagging. Throttled, because it runs off
 * movement: at a hard walk that's five sweeps a second otherwise.
 */
/obj/item/organ/eyes/robotic/cyberware/nightshade/proc/sweep_tags(force = FALSE)
	if(!force && world.time < next_sweep)
		return
	next_sweep = world.time + CYBERWARE_NIGHTSHADE_SWEEP
	if(!owner || (organ_flags & ORGAN_FAILING) || owner.stat == DEAD || !owner.client)
		clear_tags()
		return

	var/list/seen = list()
	for(var/mob/living/body in view(owner.client.view || world.view, owner))
		if(body == owner)
			continue
		seen[body] = TRUE
		if(tagged[body])
			continue
		tag_body(body)

	// Copied: untag_body mutates the list we'd otherwise be walking.
	for(var/mob/living/body as anything in tagged.Copy())
		if(seen[body] && !QDELETED(body))
			continue
		untag_body(body)

/// Hangs one bloom on one body, visible to nobody but our bearer.
/obj/item/organ/eyes/robotic/cyberware/nightshade/proc/tag_body(mob/living/body)
	var/image/bloom = image('icons/effects/light_overlays/light_32.dmi', body, "light")
	bloom.color = (body.stat == DEAD) ? CYBERWARE_NIGHTSHADE_DEAD_COLOR : CYBERWARE_NIGHTSHADE_LIVE_COLOR
	bloom.alpha = (body.stat == DEAD) ? 55 : 110
	bloom.blend_mode = BLEND_ADD
	bloom.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM | KEEP_APART
	// Above the lighting overlay, or the dark we exist to see through eats it.
	SET_PLANE_EXPLICIT(bloom, ABOVE_LIGHTING_PLANE, body)
	tagged[body] = bloom
	owner.client?.images += bloom
	RegisterSignal(body, COMSIG_QDELETING, PROC_REF(on_tagged_deleted), override = TRUE)

/// Drops one body's bloom.
/obj/item/organ/eyes/robotic/cyberware/nightshade/proc/untag_body(mob/living/body)
	var/image/bloom = tagged[body]
	tagged -= body
	if(bloom)
		owner?.client?.images -= bloom
	if(!QDELETED(body))
		UnregisterSignal(body, COMSIG_QDELETING)

/obj/item/organ/eyes/robotic/cyberware/nightshade/proc/clear_tags()
	for(var/mob/living/body as anything in tagged.Copy())
		untag_body(body)
	tagged.Cut()

/// Signal proc for [COMSIG_QDELETING] on a tagged body: stop showing a bloom
/// parented to something that's about to stop existing.
/obj/item/organ/eyes/robotic/cyberware/nightshade/proc/on_tagged_deleted(datum/source)
	SIGNAL_HANDLER
	untag_body(source)

// ---- 3. Scrapper's Knuckles -------------------------------------------

/**
 * # Scrapper's Knuckles (T1, arm hardware slots, load 1 per arm)
 *
 * Reinforced knuckle plating in the arm's one hardware slot, the first rung
 * of the ladder Gorilla Arms evicts. One slot per arm is the rule for ALL
 * arm-mounted chrome (knuckles, myomer, blades, launchers): a new piece
 * evicts whatever the arm already carries, never stacks with it. Sold as a
 * cased pair; each arm carries half the pair's load, so the incumbent
 * netting works per-arm with no special casing.
 *
 * The punch hook is the strongarm implant's EARLY_UNARMED_ATTACK pattern
 * (augments_arms.dm) with our own damage line: flat +4 on the bodypart's
 * unarmed roll against mobs, and double that total against structures and
 * machines with a clang. Deliberately absent: strongarm's x2 slam
 * multiplier, its +20 biotype bonus, and its throw. This is a workman's
 * implant, not a haymaker.
 */
/obj/item/organ/cyberimp/cyberware/scrapper
	name = "\improper Scrapper's Knuckles"
	desc = "Milled knuckle caps grafted along the metacarpals, right-arm fit. Your punches land harder, and against plating and machine housings they land about twice as hard again."
	icon_state = "scrapper"
	zone = BODY_ZONE_R_ARM
	slot = ORGAN_SLOT_RIGHT_ARM_AUG
	valid_zones = list(
		BODY_ZONE_R_ARM = ORGAN_SLOT_RIGHT_ARM_AUG,
		BODY_ZONE_L_ARM = ORGAN_SLOT_LEFT_ARM_AUG,
	)
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	aug_overlay = "scrapper_right"

/obj/item/organ/cyberimp/cyberware/scrapper/left
	desc = "Milled knuckle caps grafted along the metacarpals, left-arm fit. Your punches land harder, and against plating and machine housings they land about twice as hard again."
	zone = BODY_ZONE_L_ARM
	slot = ORGAN_SLOT_LEFT_ARM_AUG
	aug_overlay = "scrapper_left"

/obj/item/organ/cyberimp/cyberware/scrapper/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	if(ishuman(organ_owner))
		RegisterSignal(organ_owner, COMSIG_LIVING_EARLY_UNARMED_ATTACK, PROC_REF(on_punch))

/obj/item/organ/cyberimp/cyberware/scrapper/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, COMSIG_LIVING_EARLY_UNARMED_ATTACK)

/**
 * Signal proc for [COMSIG_LIVING_EARLY_UNARMED_ATTACK]. Both arms' organs
 * listen; the active-hand zone gate means exactly one acts per swing.
 * Guard set copied from strongarm: combat mode only, left-click only, no
 * hulks (their fists have their own rules), and the can_unarmed_attack
 * cancel-chain contract.
 */
/obj/item/organ/cyberimp/cyberware/scrapper/proc/on_punch(mob/living/carbon/human/source, atom/target, proximity, modifiers)
	SIGNAL_HANDLER
	var/obj/item/bodypart/active_hand = source.get_active_hand()
	if(!active_hand || active_hand.body_zone != zone || !proximity)
		return NONE
	if(!source.combat_mode || LAZYACCESS(modifiers, RIGHT_CLICK))
		return NONE
	if(HAS_TRAIT(source, TRAIT_HULK))
		return NONE
	if(organ_flags & ORGAN_FAILING) // browned out: just a fist again
		return NONE
	var/is_structure_target = ismachinery(target) || isstructure(target)
	if(!isliving(target) && !is_structure_target)
		return NONE
	// Past the last "not our punch" guard: this swing is ours from here on, so
	// stand Redline's bypass top-up down before we take the chain away. The
	// roll below reads the hand's unarmed damage, which already carries the
	// window's +8; without this the same bonus lands twice (D5).
	cyberware_unarmed_roll_paid(source)
	if(!source.can_unarmed_attack())
		return COMPONENT_SKIP_ATTACK

	var/punch_damage = CYBERWARE_SCRAPPER_PUNCH_BONUS + rand(active_hand.unarmed_damage_low, active_hand.unarmed_damage_high)
	source.changeNext_move(CLICK_CD_MELEE)

	// The knuckles are buried in a forearm. The ink is how anyone watching
	// (the wearer included) knows the punch that just landed was chrome.
	cyberware_ink_pulse(source, CYBERWARE_INK_HARD)

	if(is_structure_target)
		var/obj/smashed = target
		source.do_attack_animation(smashed, ATTACK_EFFECT_SMASH)
		smashed.take_damage(punch_damage * 2, BRUTE, MELEE, TRUE, get_dir(smashed, source))
		playsound(smashed, 'sound/effects/clang.ogg', 50, TRUE)
		log_combat(source, smashed, "punched (scrapper's knuckles)")
		return COMPONENT_CANCEL_ATTACK_CHAIN

	var/mob/living/living_target = target
	if(ishuman(living_target))
		var/mob/living/carbon/human/human_target = living_target
		if(human_target.check_block(source, punch_damage, "[source]'s reinforced punch"))
			source.do_attack_animation(living_target)
			playsound(living_target.loc, 'sound/items/weapons/punchmiss.ogg', 25, TRUE, -1)
			log_combat(source, living_target, "attempted to punch (scrapper's knuckles)")
			return COMPONENT_CANCEL_ATTACK_CHAIN

	source.do_attack_animation(living_target, ATTACK_EFFECT_PUNCH)
	playsound(living_target.loc, 'sound/items/weapons/punch1.ogg', 25, TRUE, -1)
	var/target_zone = living_target.get_random_valid_zone(source.zone_selected)
	var/armor_block = living_target.run_armor_check(target_zone, MELEE, armour_penetration = active_hand.unarmed_effectiveness)
	living_target.apply_damage(punch_damage, active_hand.attack_type, target_zone, armor_block)
	living_target.visible_message(
		span_danger("[source] punches [living_target] with a metallic crunch!"),
		span_userdanger("You're punched by [source]'s reinforced fist!"),
		span_hear("You hear a heavy crunch!"),
		COMBAT_MESSAGE_RANGE,
		source,
	)
	to_chat(source, span_danger("You punch [living_target] with your reinforced fist!"))
	log_combat(source, living_target, "punched (scrapper's knuckles)")
	return COMPONENT_CANCEL_ATTACK_CHAIN

// The pair, as sold: one case, two organs, install each arm separately.

/obj/item/storage/case/cyberware
	name = "cyberware case"
	desc = "A foam-lined chrome case from the Undertow parlor."
	icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	icon_state = "ware_case"
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/storage/case/cyberware/scrapper
	name = "\improper Scrapper's Knuckles case"
	desc = "A foam-lined chrome case holding a matched pair of Scrapper's Knuckles, one per arm. Each side installs separately, though the rig will do both in one sitting."

/obj/item/storage/case/cyberware/scrapper/PopulateContents()
	new /obj/item/organ/cyberimp/cyberware/scrapper(src)
	new /obj/item/organ/cyberimp/cyberware/scrapper/left(src)

// ---- 5. Shock Coils ----------------------------------------------------

/**
 * # Shock Coils (T1, legs, load 1)
 *
 * Reflex pistons in the calves: you spring back up from knockdowns, wet
 * floors stop being a hazard (galoshes tier, soap and ice still win),
 * and drops land soft on the MOD longfall pattern. First rung of the leg
 * ladder; Hopper Pistons evict it.
 */
/obj/item/organ/cyberimp/cyberware/shock_coils
	name = "\improper Shock Coil calf pistons"
	desc = "Spring-loaded pistons sistered along the calf bones. You get back on your feet much faster after a knockdown, keep your footing on wet decking, and walk away from drops that would break an ankle."
	icon_state = "shock_coils"
	zone = BODY_ZONE_L_LEG
	slot = ORGAN_SLOT_CYBERWARE_LEGS
	// Sleeved over both calves, so a surgeon may open either one to fit it. Both
	// zones map to the one leg slot, so this is an incision site and nothing
	// more - swap_zone() can never turn one piece of leg chrome into two.
	valid_zones = list(
		BODY_ZONE_L_LEG = ORGAN_SLOT_CYBERWARE_LEGS,
		BODY_ZONE_R_LEG = ORGAN_SLOT_CYBERWARE_LEGS,
	)
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	aug_overlay = "shock_coils"
	organ_traits = list(TRAIT_NO_SLIP_WATER)
	/// TRUE while the knockdown/stun physiology mods are applied. Guards the
	/// failing-gated passive hooks against ever double-multiplying.
	var/reflex_mods_applied = FALSE

/obj/item/organ/cyberimp/cyberware/shock_coils/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_LIVING_Z_IMPACT, PROC_REF(on_z_impact))

// The knockdown/stun mods live in the failing-gated passive hooks (BAL-4):
// EMP-scrambled or browned-out coils are dead springs, so the mods drop with
// the rest of the ware and return when it reboots or gets repaired.
// Physiology persists across species changes (physiology.dm:1), so a single
// apply/remove pair per flip is safe, no species-gain re-hook needed.
/obj/item/organ/cyberimp/cyberware/shock_coils/chrome_passives_on(mob/living/carbon/bearer)
	. = ..()
	if(reflex_mods_applied || !ishuman(bearer))
		return
	reflex_mods_applied = TRUE
	var/mob/living/carbon/human/human_bearer = bearer
	human_bearer.physiology.knockdown_mod *= 0.5
	human_bearer.physiology.stun_mod *= 0.8

/obj/item/organ/cyberimp/cyberware/shock_coils/chrome_passives_off(mob/living/carbon/bearer)
	. = ..()
	if(!reflex_mods_applied)
		return
	// Reset the latch before any bearer-validity skip, or a ware pulled off a
	// deleting mob would stay marked applied and never re-arm for the next one.
	reflex_mods_applied = FALSE
	if(!ishuman(bearer) || QDELETED(bearer))
		return
	var/mob/living/carbon/human/human_bearer = bearer
	human_bearer.physiology.knockdown_mod /= 0.5
	human_bearer.physiology.stun_mod /= 0.8

/obj/item/organ/cyberimp/cyberware/shock_coils/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, COMSIG_LIVING_Z_IMPACT)

/// Signal proc for [COMSIG_LIVING_Z_IMPACT]: the MOD longfall pattern,
/// minus the suit's power cost. Big multi-level drops still stagger.
/obj/item/organ/cyberimp/cyberware/shock_coils/proc/on_z_impact(datum/source, levels, turf/fell_on)
	SIGNAL_HANDLER
	if(organ_flags & ORGAN_FAILING)
		return NONE
	new /obj/effect/temp_visual/mook_dust(fell_on)
	cyberware_ink_pulse(owner, CYBERWARE_INK_SOFT)
	if(levels >= 2)
		owner.adjust_staggered_up_to(STAGGERED_SLOWDOWN_LENGTH * levels, 10 SECONDS)
	owner.visible_message(
		span_notice("[owner] lands on [fell_on] with a piston hiss."),
		span_notice("Your shock coils soak up the impact."),
	)
	return ZIMPACT_CANCEL_DAMAGE | ZIMPACT_NO_MESSAGE | ZIMPACT_NO_SPIN

// ---- 7. Gastro Reactor -------------------------------------------------

/**
 * # Gastro Reactor (T1, chest, gut slot, load 1)
 *
 * A processing gut that treats food as feedstock. Three legs, all live
 * primitives: TRAIT_STRONG_STOMACH covers floor food and halves vomit
 * losses, TRAIT_VORACIOUS is tg's eat-fast trait, and the perceived-quality
 * signal lifts rotten/gross fare back above the disgust thresholds so it
 * goes down clean. A continuous disgust scrub mops up whatever still gets
 * through, you never build to retching. Species-toxic foodtypes stay
 * toxic (the quality chain early-returns before our bonus applies), which
 * is the addendum's "edible things only" rescope.
 */
/obj/item/organ/cyberimp/cyberware/gastro
	name = "\improper Gastro Reactor"
	desc = "A ceramic-lined digester where your stomach used to be. Rot, floor scrapings, whatever was in the back of the fridge. It all burns the same, faster than a real gut and without the food poisoning."
	icon_state = "gastro"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_GUT
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	organ_traits = list(TRAIT_STRONG_STOMACH, TRAIT_VORACIOUS)

/obj/item/organ/cyberimp/cyberware/gastro/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_LIVING_GET_PERCEIVED_FOOD_QUALITY, PROC_REF(on_food_quality))

/obj/item/organ/cyberimp/cyberware/gastro/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, COMSIG_LIVING_GET_PERCEIVED_FOOD_QUALITY)

/// Signal proc for [COMSIG_LIVING_GET_PERCEIVED_FOOD_QUALITY]: everything
/// tastes like fuel, which is to say fine.
/obj/item/organ/cyberimp/cyberware/gastro/proc/on_food_quality(mob/living/source, datum/component/edible/food, list/extra_quality)
	SIGNAL_HANDLER
	if(organ_flags & ORGAN_FAILING)
		return
	extra_quality += CYBERWARE_GASTRO_QUALITY_BONUS

/obj/item/organ/cyberimp/cyberware/gastro/on_life(seconds_per_tick, times_fired)
	. = ..()
	if(organ_flags & ORGAN_FAILING)
		return
	if(owner.disgust > 0)
		owner.adjust_disgust(-CYBERWARE_GASTRO_DISGUST_PURGE * seconds_per_tick)

// ---- 9. Cargo Cavity ---------------------------------------------------

/**
 * # Cargo Cavity (T1, chest, stash slot, load 1, ORGAN_HIDDEN)
 *
 * One small item, inside your chest, off every manifest: ORGAN_HIDDEN
 * keeps it out of health analyzers, and the strip UI never lists organs,
 * PvP loot protection is the intended use. Deliberately NOT a storage
 * component (ABSTRACT/NODROP conflicts); a single tracked ref plus an
 * organ action does the whole job. The stash rides the organ on removal,
 * and the cyberware base's Destroy drops contents rather than eating them.
 */
/obj/item/organ/cyberimp/cyberware/cargo_cavity
	name = "\improper Cargo Cavity"
	desc = "A shielded compartment plumbed into the ribcage, sized for one small item. Scanners read straight past it and a pat-down won't find it."
	icon_state = "cargo_cavity"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_STASH
	organ_flags = ORGAN_ROBOTIC | ORGAN_HIDDEN
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	actions_types = list(/datum/action/item_action/organ_action/use)
	/// The one item riding in the cavity.
	var/obj/item/stashed

/obj/item/organ/cyberimp/cyberware/cargo_cavity/examine(mob/user)
	. = ..()
	if(stashed)
		. += span_notice("[stashed] is packed inside.")

/obj/item/organ/cyberimp/cyberware/cargo_cavity/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == stashed)
		stashed = null

/// One button, two verbs: empty cavity swallows the active-hand item,
/// loaded cavity hands it back.
/obj/item/organ/cyberimp/cyberware/cargo_cavity/ui_action_click()
	if(organ_flags & ORGAN_FAILING)
		owner.balloon_alert(owner, "cavity seized shut!")
		return
	if(stashed)
		var/obj/item/returned = stashed
		returned.forceMove(owner.drop_location())
		owner.put_in_hands(returned)
		owner.balloon_alert(owner, "[returned.name] ejected")
		playsound(owner, 'sound/machines/click.ogg', 30, TRUE)
		cyberware_ink_pulse(owner, CYBERWARE_INK_SOFT)
		return
	var/obj/item/held = owner.get_active_held_item()
	if(!held)
		owner.balloon_alert(owner, "nothing in hand!")
		return
	if(held.w_class > CYBERWARE_CAVITY_MAX_WCLASS)
		owner.balloon_alert(owner, "too big for the cavity!")
		return
	if((held.item_flags & ABSTRACT) || HAS_TRAIT(held, TRAIT_NODROP))
		owner.balloon_alert(owner, "it won't come loose!")
		return
	if(!owner.transferItemToLoc(held, src))
		owner.balloon_alert(owner, "it won't come loose!")
		return
	stashed = held
	owner.balloon_alert(owner, "[held.name] stashed away")
	playsound(owner, 'sound/items/eatfood.ogg', 20, TRUE)
	cyberware_ink_pulse(owner, CYBERWARE_INK_SOFT)

// ---- 10. Dermal Mesh ---------------------------------------------------

/datum/armor/cyberware_dermal_mesh
	melee = 15
	bullet = 15
	laser = 10
	wound = 5

/**
 * # Dermal Mesh (T1, chest, dermal slot, load 2)
 *
 * Light woven plating under the skin, the roach-organ physiology armor
 * pattern. Sized so that two points of load buys something you can feel in a
 * scrap rather than a rounding error: 15 melee/bullet, a little laser, and
 * enough wound resistance to keep a bad hit from opening you up. Still a
 * long way under the Slabskin Plate that evicts it, which is the point.
 * Physiology explicitly survives species changes (physiology.dm:1), so one
 * add/subtract pair per flip is the whole lifecycle; re-applying on species
 * gain would stack the armor. The pair rides the failing-gated passive hooks
 * (BAL-4): EMP-scrambled or browned-out mesh armors nothing.
 */
/obj/item/organ/cyberimp/cyberware/dermal_mesh
	name = "\improper Dermal Mesh weave"
	desc = "A subdermal lattice of impact polymer. It won't stop anything serious, but knives and small arms hurt noticeably less and the skin over it doesn't tear so easily."
	icon_state = "dermal_mesh"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_DERMAL
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 2
	tier = CYBERWARE_TIER_1
	aug_overlay = "dermal_mesh"
	/// Armor mixed into the bearer's physiology while installed and running.
	var/datum/armor/mesh_armor = /datum/armor/cyberware_dermal_mesh
	/// TRUE while mesh_armor is mixed in; guards against double add/subtract.
	var/mesh_armor_applied = FALSE

/obj/item/organ/cyberimp/cyberware/dermal_mesh/chrome_passives_on(mob/living/carbon/bearer)
	. = ..()
	if(mesh_armor_applied || !ishuman(bearer))
		return
	mesh_armor_applied = TRUE
	var/mob/living/carbon/human/human_bearer = bearer
	human_bearer.physiology.armor = human_bearer.physiology.armor.add_other_armor(mesh_armor)

/obj/item/organ/cyberimp/cyberware/dermal_mesh/chrome_passives_off(mob/living/carbon/bearer)
	. = ..()
	if(!mesh_armor_applied)
		return
	mesh_armor_applied = FALSE // reset before the validity skip, see Shock Coils
	if(!ishuman(bearer) || QDELETED(bearer))
		return
	var/mob/living/carbon/human/human_bearer = bearer
	human_bearer.physiology.armor = human_bearer.physiology.armor.subtract_other_armor(mesh_armor)

// ---- 11. Gecko Grips ---------------------------------------------------

/**
 * # Gecko Grips (T1, arm, hands slot, load 1)
 *
 * Setae-pad palms. Three things, all of which you should be able to feel:
 *
 * 1. Your hands do not open when the lights go out. Rather than pre-clamping
 *    off the stun signals (which only covered the handful of statuses we
 *    thought to list, and lost every race against living's own
 *    HANDS_BLOCKED handler, that one is registered at mob init and always
 *    runs first), the pads simply refuse the involuntary drop itself: a
 *    guard rides COMSIG_ITEM_PRE_UNEQUIP on whatever is in your hands and
 *    cancels the unequip while your hands are blocked by trauma. That covers
 *    stuns, paralysis, unconsciousness, stamina collapse and crit with one
 *    rule. Two carve-outs keep it honest. Restraints still take your hands
 *    (cuffs beat chrome), and a corpse can still be looted.
 * 2. Tables read as flat ground: TRAIT_PASSTABLE to walk straight over them,
 *    TRAIT_FREERUNNING so anything you do have to climb is instant.
 * 3. A chasm lip-catch. The catch arms TRAIT_CHASM_STOPPER on you (the chasm
 *    component refuses to drop anything on a tile containing a STOPPER);
 *    stepping onto a chasm consumes it. You're shoved back to the lip and
 *    the pads need [CYBERWARE_GECKO_CATCH_COOLDOWN/10]s to re-set, during
 *    which chasms are exactly as lethal as ever.
 *
 * Kept from the anti-drop implant it apes: the EMP tradeoff. A pulse spasms
 * the pads open, hurls whatever you're holding, and leaves the grip dead for
 * the reboot, chrome that holds on forever would have no counterplay.
 */
/obj/item/organ/cyberimp/cyberware/gecko
	name = "\improper Gecko Grip palm pads"
	desc = "Setae pads laminated into the palms, running the same trick geckos do. Your hands clamp shut on whatever you're holding when you go down, so nobody strips your gun off you, and you can cross tables like flat ground and catch a ledge on the way into a chasm. Cuffs still work fine."
	icon_state = "gecko"
	zone = BODY_ZONE_R_ARM
	slot = ORGAN_SLOT_CYBERWARE_HANDS
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	organ_traits = list(TRAIT_FREERUNNING)
	/// Whether the chasm catch is armed.
	var/catch_ready = TRUE
	/// Held items carrying our pre-unequip guard, so removal can lift them.
	var/list/guarded = list()
	/// world.time the clamp last told the room about itself, so a burst of
	/// blocked drops is one message rather than six.
	var/last_clamp_beat = 0

/obj/item/organ/cyberimp/cyberware/gecko/examine(mob/user)
	. = ..()
	. += span_notice("The pads are [catch_ready ? "set" : "re-setting"] for a chasm catch.")

/obj/item/organ/cyberimp/cyberware/gecko/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_MOB_EQUIPPED_ITEM, PROC_REF(on_item_equipped))
	RegisterSignal(organ_owner, COMSIG_MOB_UNEQUIPPED_ITEM, PROC_REF(on_item_unequipped))
	RegisterSignal(organ_owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	// Upstream deleted the passtable_on()/passtable_off() wrappers; the trait they
	// set is still the mechanism, and REF(src) was already the source key.
	ADD_TRAIT(organ_owner, TRAIT_PASSTABLE, REF(src))
	// Whatever they were already holding when the pads went in.
	for(var/obj/item/held in organ_owner.held_items)
		guard_item(held)
	if(catch_ready)
		ADD_TRAIT(organ_owner, TRAIT_CHASM_STOPPER, REF(src))

/obj/item/organ/cyberimp/cyberware/gecko/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	drop_guards()
	UnregisterSignal(organ_owner, list(COMSIG_MOB_EQUIPPED_ITEM, COMSIG_MOB_UNEQUIPPED_ITEM, COMSIG_MOVABLE_MOVED))
	REMOVE_TRAIT(organ_owner, TRAIT_PASSTABLE, REF(src))
	REMOVE_TRAIT(organ_owner, TRAIT_CHASM_STOPPER, REF(src))

/obj/item/organ/cyberimp/cyberware/gecko/Destroy()
	drop_guards()
	return ..()

// ---- The clamp ---------------------------------------------------------

/// Signal proc for [COMSIG_MOB_EQUIPPED_ITEM]: anything that lands in a hand
/// gets the guard. Other slots are none of our business.
/obj/item/organ/cyberimp/cyberware/gecko/proc/on_item_equipped(datum/source, obj/item/equipped, slot)
	SIGNAL_HANDLER
	if(!(slot & ITEM_SLOT_HANDS))
		return
	guard_item(equipped)

/// Signal proc for [COMSIG_MOB_UNEQUIPPED_ITEM]: a drop we allowed (or that
/// was forced past us), stop watching it.
/obj/item/organ/cyberimp/cyberware/gecko/proc/on_item_unequipped(datum/source, obj/item/unequipped)
	SIGNAL_HANDLER
	unguard_item(unequipped)

/obj/item/organ/cyberimp/cyberware/gecko/proc/guard_item(obj/item/held)
	if(QDELETED(held) || (held in guarded))
		return
	guarded += held
	RegisterSignal(held, COMSIG_ITEM_PRE_UNEQUIP, PROC_REF(on_item_pre_unequip), override = TRUE)
	RegisterSignal(held, COMSIG_QDELETING, PROC_REF(on_guarded_deleted), override = TRUE)

/obj/item/organ/cyberimp/cyberware/gecko/proc/unguard_item(obj/item/held)
	if(!(held in guarded))
		return
	guarded -= held
	if(!QDELETED(held))
		UnregisterSignal(held, list(COMSIG_ITEM_PRE_UNEQUIP, COMSIG_QDELETING))

/obj/item/organ/cyberimp/cyberware/gecko/proc/drop_guards()
	for(var/obj/item/held as anything in guarded.Copy())
		unguard_item(held)
	guarded.Cut()

/// Signal proc for [COMSIG_QDELETING] on a guarded item.
/obj/item/organ/cyberimp/cyberware/gecko/proc/on_guarded_deleted(datum/source)
	SIGNAL_HANDLER
	unguard_item(source)

/**
 * Is something other than restraints currently blocking our bearer's hands?
 *
 * TRAIT_HANDS_BLOCKED is the one trait every hand-stripping condition adds,
 * which is exactly why we have to read its SOURCES rather than the trait: a
 * pair of cuffs adds it too, and chrome that beat handcuffs would be a very
 * different (and much more expensive) piece of hardware. Anything else.
 * Stun, paralysis, unconsciousness, stamina collapse, crit, is what the
 * pads are for.
 */
/obj/item/organ/cyberimp/cyberware/gecko/proc/hands_blocked_by_trauma()
	if(!owner || (organ_flags & ORGAN_FAILING))
		return FALSE
	if(owner.stat == DEAD) // dead hands let go; corpses stay lootable
		return FALSE
	for(var/source in GET_TRAIT_SOURCES(owner, TRAIT_HANDS_BLOCKED))
		if(source != TRAIT_RESTRAINED)
			return TRUE
	return FALSE

/**
 * Signal proc for [COMSIG_ITEM_PRE_UNEQUIP] on a held item. The whole clamp,
 * in one branch: while the bearer is down, involuntary drops are refused.
 * A forced unequip is never offered to us at all (doUnEquip only honors the
 * block when force is FALSE), so admin work and gibbing are unaffected.
 */
/obj/item/organ/cyberimp/cyberware/gecko/proc/on_item_pre_unequip(obj/item/source, force, atom/newloc, no_move, invdrop, silent)
	SIGNAL_HANDLER
	if(force || !owner?.is_holding(source))
		return NONE
	if(!hands_blocked_by_trauma())
		return NONE
	clamp_beat(source)
	return COMPONENT_ITEM_BLOCK_UNEQUIP

/// The tell. Throttled so one knockout is one beat, not one per hand.
/obj/item/organ/cyberimp/cyberware/gecko/proc/clamp_beat(obj/item/kept)
	if(world.time < last_clamp_beat + 2 SECONDS)
		return
	last_clamp_beat = world.time
	owner.visible_message(
		span_notice("[owner]'s hands lock shut around [kept]."),
		span_notice("Your grips clamp down on [kept]."),
		vision_distance = COMBAT_MESSAGE_RANGE,
	)
	playsound(owner, 'sound/machines/click.ogg', 35, TRUE)
	cyberware_ink_pulse(owner, CYBERWARE_INK_HARD)

// ---- The chasm catch ---------------------------------------------------

/**
 * Signal proc for [COMSIG_MOVABLE_MOVED]: the chasm lip-catch. The passive
 * STOPPER trait is what kept the chasm from swallowing us during Entered;
 * by the time Moved fires we're standing on the lip and can pay for it,
 * shove back to the previous turf, disarm the trait, and re-set later.
 */
/obj/item/organ/cyberimp/cyberware/gecko/proc/on_moved(mob/living/source, atom/old_loc, movement_dir, forced)
	SIGNAL_HANDLER
	if(!catch_ready || (organ_flags & ORGAN_FAILING))
		return
	if(source.throwing) // sailing over a chasm is the throw's business, not ours
		return
	var/turf/here = get_turf(source)
	if(!ischasm(here))
		return
	var/turf/lip = old_loc
	if(!isturf(lip) || ischasm(lip) || get_dist(here, lip) > 1)
		return // thrown/teleported in. The passive trait already did its best
	catch_ready = FALSE
	REMOVE_TRAIT(source, TRAIT_CHASM_STOPPER, REF(src))
	source.forceMove(lip)
	source.balloon_alert(source, "grips catch the lip!")
	playsound(source, 'sound/effects/pickaxe/picaxe2.ogg', 40, TRUE)
	cyberware_ink_pulse(source, CYBERWARE_INK_FLARE)
	addtimer(CALLBACK(src, PROC_REF(rearm_catch)), CYBERWARE_GECKO_CATCH_COOLDOWN)

/obj/item/organ/cyberimp/cyberware/gecko/proc/rearm_catch()
	catch_ready = TRUE
	if(owner)
		ADD_TRAIT(owner, TRAIT_CHASM_STOPPER, REF(src))
		owner.balloon_alert(owner, "grips re-set")

/// The anti-drop implant's signature tradeoff, kept on purpose: an EMP
/// spasms the pads and everything you hold goes flying. The clamp lets go on
/// its own, the parent's ..() has already flipped us ORGAN_FAILING, which is
/// exactly what hands_blocked_by_trauma() reads, so these stay ordinary
/// unforced drops and anything genuinely NODROP (a deployed blade) stays put.
/obj/item/organ/cyberimp/cyberware/gecko/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF || !owner)
		return
	var/throw_range = (severity == EMP_HEAVY) ? 5 : 3
	var/list/possible_targets = oview(throw_range, owner)
	if(!length(possible_targets))
		return
	for(var/obj/item/held in owner.held_items)
		if(!owner.dropItemToGround(held))
			continue
		held.throw_at(pick(possible_targets), throw_range, 2)
		to_chat(owner, span_warning("Your hand spasms open and hurls [held]!"))

#undef CYBERWARE_SCRAPPER_PUNCH_BONUS
#undef CYBERWARE_GECKO_CATCH_COOLDOWN
#undef CYBERWARE_GASTRO_DISGUST_PURGE
#undef CYBERWARE_GASTRO_QUALITY_BONUS
#undef CYBERWARE_CAVITY_MAX_WCLASS
