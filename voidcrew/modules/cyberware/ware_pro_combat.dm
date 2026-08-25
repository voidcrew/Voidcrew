/**
 * # Tier 2 combat chrome
 *
 * Deadeye Link, Slipwire, Dead Channel, Hopper Pistons, plus the two pieces
 * of shared infrastructure the combat roster leans on:
 *
 * - /datum/component/cyberware_dodge: THE one projectile-dodge arbiter.
 *   Slipwire registers a 15% source here, Cascade Lattice (ware_legend.dm)
 *   registers a 40% source during its window, and the component rolls the
 *   single HIGHEST live source. Never additive: Slipwire + Cascade together
 *   is still 40%, not 49%. Any future dodge chrome must register a source
 *   through cyberware_register_dodge_source() rather than hanging its own
 *   COMSIG_ATOM_PRE_BULLET_ACT handler.
 * - cyberware_is_ally(): the crew filter for auto-targeting ware (Deadeye's
 *   tag, Widowline's cleave). Allies are people who share a ship team with
 *   you; NPC boarders standing on your deck are NOT allies, and rival players
 *   are fair game. Manual swings never consult this, it exists only so
 *   automatic effects can't be aimed at your own crew.
 */

// ---- Shared dodge arbiter ----------------------------------------------

/// A dodge source only fires while its bearer moved within this window.
#define CYBERWARE_DODGE_MOVE_WINDOW (1 SECONDS)

/**
 * The one dodge roll for all cyberware. Lives on the mob; wares and status
 * effects contribute keyed callback sources returning their CURRENT chance
 * (0 when browned out / windowless), and the component resolves each incoming
 * hostile projectile against the single highest chance.
 *
 * House rules, per the design freeze:
 * - Moving-only: no dodge unless the bearer moved within the last second.
 * - Never point-blank: adjacent shooters always hit.
 * - Always visible and audible: the dodge is a one-tile blur sidestep with a
 *   fading decoy and a bullet-miss crack. Dodging reads to the shooter.
 * - COMPONENT_BULLET_PIERCED means the round keeps flying into whoever is
 *   behind; accepted as flavor.
 */
/datum/component/cyberware_dodge
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// key -> /datum/callback returning that source's live dodge chance.
	var/list/dodge_sources = list()
	/// world.time of the bearer's last move.
	var/last_move_time = 0

/datum/component/cyberware_dodge/Initialize()
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/cyberware_dodge/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_PRE_BULLET_ACT, PROC_REF(on_pre_bullet_act))
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))

/datum/component/cyberware_dodge/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_ATOM_PRE_BULLET_ACT, COMSIG_MOVABLE_MOVED))

/datum/component/cyberware_dodge/Destroy()
	dodge_sources = null
	return ..()

/// Signal proc for [COMSIG_MOVABLE_MOVED]: timestamp the movement window.
/datum/component/cyberware_dodge/proc/on_moved(atom/movable/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	last_move_time = world.time

/// Signal proc for [COMSIG_ATOM_PRE_BULLET_ACT]: the actual dodge roll.
/datum/component/cyberware_dodge/proc/on_pre_bullet_act(mob/living/source, obj/projectile/hitting_projectile, def_zone, piercing_hit, blocked)
	SIGNAL_HANDLER
	if(world.time - last_move_time > CYBERWARE_DODGE_MOVE_WINDOW)
		return NONE
	if(source.stat != STABLE || source.body_position == LYING_DOWN || source.buckled)
		return NONE
	if(!istype(hitting_projectile) || !hitting_projectile.is_hostile_projectile())
		return NONE
	// Point-blank shots always land: an adjacent shooter is inside the
	// reflex loop. This is the anti-"unhittable in a brawl" rule.
	var/atom/shooter = hitting_projectile.firer
	if(shooter && shooter != source && get_dist(source, shooter) <= 1)
		return NONE
	var/best_chance = 0
	for(var/key in dodge_sources)
		var/datum/callback/chance_callback = dodge_sources[key]
		var/chance = chance_callback?.Invoke()
		if(isnum(chance))
			best_chance = max(best_chance, chance)
	if(best_chance <= 0 || !prob(best_chance))
		return NONE
	INVOKE_ASYNC(src, PROC_REF(perform_sidestep), source, hitting_projectile)
	return COMPONENT_BULLET_PIERCED

/// The visible half of a successful dodge: blur decoy, bullet-miss crack,
/// and a one-tile sidestep perpendicular to the shot when the floor allows.
/datum/component/cyberware_dodge/proc/perform_sidestep(mob/living/source, obj/projectile/dodged)
	if(QDELETED(source))
		return
	new /obj/effect/temp_visual/decoy/fading/halfsecond(source.loc, source)
	playsound(source, SFX_BULLET_MISS, 60, TRUE)
	source.visible_message(
		span_danger("[source] blurs sideways out of [dodged]'s path!"),
		span_danger("You blur out of [dodged]'s path!"),
	)
	var/incoming_dir = QDELETED(dodged) ? source.dir : dodged.dir
	var/list/side_dirs = shuffle(list(turn(incoming_dir, 90), turn(incoming_dir, -90)))
	for(var/step_dir in side_dirs)
		if(step(source, step_dir))
			break

/**
 * Adds (or refreshes) a keyed dodge source on the bearer, creating the
 * arbiter component on first use. The callback is polled per incoming
 * projectile and must return the source's CURRENT chance, return 0 while
 * disabled (ORGAN_FAILING etc.) rather than unregistering per-flicker.
 */
/proc/cyberware_register_dodge_source(mob/living/bearer, key, datum/callback/chance_callback)
	if(!istype(bearer) || !key || !chance_callback)
		return
	var/datum/component/cyberware_dodge/arbiter = bearer.LoadComponent(/datum/component/cyberware_dodge)
	arbiter.dodge_sources[key] = chance_callback

/// Removes a keyed dodge source; the arbiter cleans itself up with the last one.
/proc/cyberware_unregister_dodge_source(mob/living/bearer, key)
	var/datum/component/cyberware_dodge/arbiter = bearer?.GetComponent(/datum/component/cyberware_dodge)
	if(!arbiter)
		return
	arbiter.dodge_sources -= key
	if(!length(arbiter.dodge_sources))
		qdel(arbiter)

// ---- Shared ally filter ------------------------------------------------

/**
 * The ship team this mob is crew of, or null. Checks the ship they are
 * standing on first (free), then the global register, so crewmates raiding
 * a ruin together still read as one crew with the hull parked outside.
 */
/proc/cyberware_crew_team(mob/living/crewmate)
	if(!istype(crewmate) || !crewmate.mind)
		return null
	var/obj/structure/overmap/ship/standing_on = get_ship_from_atom(crewmate)
	if(standing_on?.ship_team && (crewmate.mind in standing_on.ship_team.members))
		return standing_on.ship_team
	for(var/obj/structure/overmap/ship/candidate as anything in SSovermap.simulated_ships)
		if(QDELETED(candidate) || !candidate.ship_team)
			continue
		if(crewmate.mind in candidate.ship_team.members)
			return candidate.ship_team
	return null

/**
 * TRUE when target is someone this user's AUTO-targeting chrome must refuse:
 * themselves, or a fellow crew member of the same ship team. Mindless mobs
 * are never allies (an NPC boarder on your own deck stays a valid target),
 * and rival players are always fair game. This is a PvP server.
 */
/proc/cyberware_is_ally(mob/living/user, mob/living/target)
	if(user == target)
		return TRUE
	if(!istype(user) || !istype(target))
		return FALSE
	var/datum/team/user_team = cyberware_crew_team(user)
	if(!user_team)
		return FALSE
	return cyberware_crew_team(target) == user_team

// =========================================================================
// DEADEYE LINK
// =========================================================================

/// How far a tag can be planted, and how far homing keeps correcting.
#define CYBERWARE_DEADEYE_TAG_RANGE 9
/// Homing shots granted per tag.
#define CYBERWARE_DEADEYE_TAG_SHOTS 3
/// The tag dies on its own after this long, spent or not, homing windows
/// stay short (homing projectiles revert to segmented processing; perf).
#define CYBERWARE_DEADEYE_TAG_DURATION (15 SECONDS)
/// Filter key for the reticle painted on the tagged target.
#define CYBERWARE_DEADEYE_MARK_FILTER "deadeye_mark"

/**
 * # Deadeye Link (T2, eyes, load 3)
 *
 * Milspec optics with an active target processor: tag a hostile in view and
 * your next three shots hard-track them. The tag is an explicit click.
 * Nothing is ever auto-acquired, and refuses your own crew outright. The
 * reticle on the victim is visible to everyone including the victim, and
 * every homing round paints a crosshair flash as it corrects: getting
 * deadeye'd is loud, legible, and answered by breaking line of sight.
 */
/obj/item/organ/eyes/robotic/cyberware/deadeye
	name = "\improper Deadeye link"
	desc = "Milspec optics built around a target-processing coprocessor. Paint someone and the link walks your next few rounds onto them, whatever the barrel was actually pointed at."
	icon_state = "deadeye"
	chrome_load = 3
	tier = CYBERWARE_TIER_2
	actions_types = list(
		/datum/action/cooldown/cyberware/deadeye_tag,
		/datum/action/cooldown/cyberware/chrome_read,
	)
	/// Weakref to the currently tagged target.
	var/datum/weakref/tagged_ref
	/// Homing shots remaining on the current tag.
	var/shots_left = 0
	/// Expiry timer for the current tag.
	var/tag_timer

/obj/item/organ/eyes/robotic/cyberware/deadeye/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	end_tag(organ_owner)

/obj/item/organ/eyes/robotic/cyberware/deadeye/Destroy()
	end_tag(owner)
	return ..()

/// Opens a tag on the target: paints the reticle, arms the shot counter, and
/// starts listening for the bearer's outgoing projectiles.
/obj/item/organ/eyes/robotic/cyberware/deadeye/proc/start_tag(mob/living/target)
	end_tag(owner)
	tagged_ref = WEAKREF(target)
	shots_left = CYBERWARE_DEADEYE_TAG_SHOTS
	RegisterSignal(owner, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE, PROC_REF(on_owner_fired))
	target.add_filter(CYBERWARE_DEADEYE_MARK_FILTER, 2, list("type" = "outline", "color" = "#ff3300", "size" = 1))
	new /obj/effect/temp_visual/smartgun_target(get_turf(target))
	playsound(owner, 'sound/machines/synth/synth_yes.ogg', 30, TRUE)
	owner.balloon_alert(owner, "target tagged")
	to_chat(target, span_userdanger("A red targeting glint settles on you!"))
	tag_timer = addtimer(CALLBACK(src, PROC_REF(on_tag_expired)), CYBERWARE_DEADEYE_TAG_DURATION, TIMER_STOPPABLE)

/obj/item/organ/eyes/robotic/cyberware/deadeye/proc/on_tag_expired()
	tag_timer = null
	end_tag(owner)

/// Tears the tag down: reticle off, counter cleared, signal released.
/obj/item/organ/eyes/robotic/cyberware/deadeye/proc/end_tag(mob/living/carbon/bearer)
	var/mob/living/target = tagged_ref?.resolve()
	if(target)
		target.remove_filter(CYBERWARE_DEADEYE_MARK_FILTER)
	tagged_ref = null
	shots_left = 0
	if(tag_timer)
		deltimer(tag_timer)
		tag_timer = null
	if(bearer)
		UnregisterSignal(bearer, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE)

/**
 * Signal proc for [COMSIG_PROJECTILE_FIRER_BEFORE_FIRE] on the bearer: walk
 * the outgoing round onto the tagged target. Fires before the projectile
 * launches, so set_homing_target() steers it from the first tile.
 */
/obj/item/organ/eyes/robotic/cyberware/deadeye/proc/on_owner_fired(mob/living/user, obj/projectile/projectile, datum/fired_from, atom/clicked_atom)
	SIGNAL_HANDLER
	if(organ_flags & ORGAN_FAILING)
		return
	if(!istype(projectile))
		return
	var/mob/living/target = tagged_ref?.resolve()
	if(QDELETED(target) || target.stat == DEAD || target.z != user.z || get_dist(user, target) > CYBERWARE_DEADEYE_TAG_RANGE)
		end_tag(user)
		return
	projectile.set_homing_target(target)
	projectile.homing_turn_speed = max(projectile.homing_turn_speed, 30)
	new /obj/effect/temp_visual/smartgun_target(get_turf(target))
	shots_left--
	if(shots_left <= 0)
		end_tag(user)

/datum/action/cooldown/cyberware/deadeye_tag
	name = "Deadeye Tag"
	desc = "Tag a hostile in view. Your next three shots track them automatically. The tag refuses to take a crewmate."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "sniper_zoom"
	cooldown_time = 25 SECONDS
	click_to_activate = TRUE

/datum/action/cooldown/cyberware/deadeye_tag/Activate(atom/target)
	var/obj/item/organ/eyes/robotic/cyberware/deadeye/optics = organ
	if(!istype(optics) || !isliving(owner))
		return FALSE
	if(!isliving(target))
		owner.balloon_alert(owner, "no target lock!")
		return FALSE
	var/mob/living/victim = target
	if(victim == owner || victim.stat == DEAD)
		owner.balloon_alert(owner, "no target lock!")
		return FALSE
	if(cyberware_is_ally(owner, victim))
		owner.balloon_alert(owner, "friendly, tag refused!")
		return FALSE
	if(!can_see(owner, victim, CYBERWARE_DEADEYE_TAG_RANGE))
		owner.balloon_alert(owner, "no line of sight!")
		return FALSE
	StartCooldown()
	optics.start_tag(victim)
	return TRUE

// =========================================================================
// SLIPWIRE
// =========================================================================

/// Slipwire's while-moving dodge chance (ADDENDUM 2: 15, not 20).
#define CYBERWARE_SLIPWIRE_DODGE_CHANCE 15

/**
 * # Slipwire (T2, chest, nervous slot, load 4)
 *
 * A reflex shunt spliced through the spinal trunk. While you are moving,
 * 15% of incoming projectiles are answered with a visible one-tile blur
 * sidestep (never point-blank, never while browned out) plus a small
 * always-on gait boost. The dodge itself lives in the shared arbiter above;
 * this organ just contributes a source whose chance drops to zero the moment
 * the ware is EMP-scrambled or browned out.
 */
/obj/item/organ/cyberimp/cyberware/slipwire
	name = "\improper Slipwire reflex shunt"
	desc = "A reflex arc spliced in parallel with the spinal trunk. While you're moving it sidesteps incoming fire on its own, roughly one shot in seven misses because your body moved before you told it to."
	icon_state = "slipwire"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_NERVOUS
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 4
	tier = CYBERWARE_TIER_2

/obj/item/organ/cyberimp/cyberware/slipwire/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	cyberware_register_dodge_source(organ_owner, REF(src), CALLBACK(src, PROC_REF(get_dodge_chance)))

/obj/item/organ/cyberimp/cyberware/slipwire/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	cyberware_unregister_dodge_source(organ_owner, REF(src))

// The gait boost rides the failing-gated passive layer (BAL-4): the dodge
// already zeroed itself while failing (get_dodge_chance), but the speed kept
// running through EMP downtime. Movespeed modifiers are keyed by type, so
// add/remove is idempotent and needs no applied-state guard.
/obj/item/organ/cyberimp/cyberware/slipwire/chrome_passives_on(mob/living/carbon/bearer)
	. = ..()
	bearer?.add_movespeed_modifier(/datum/movespeed_modifier/cyberware_slipwire)

/obj/item/organ/cyberimp/cyberware/slipwire/chrome_passives_off(mob/living/carbon/bearer)
	. = ..()
	bearer?.remove_movespeed_modifier(/datum/movespeed_modifier/cyberware_slipwire)

/// Dodge-source callback: dead weight while failing, 15% otherwise.
/obj/item/organ/cyberimp/cyberware/slipwire/proc/get_dodge_chance()
	if(organ_flags & ORGAN_FAILING)
		return 0
	return CYBERWARE_SLIPWIRE_DODGE_CHANCE

/datum/movespeed_modifier/cyberware_slipwire
	multiplicative_slowdown = -0.1

// =========================================================================
// DEAD CHANNEL
// =========================================================================

/// Dead Channel halves incoming stamina damage.
#define CYBERWARE_DEAD_CHANNEL_STAMINA_MULT 0.5
/// Fully desaturated at (this fraction) of max health lost; the last colour
/// drains out just before hard crit.
#define CYBERWARE_DEAD_CHANNEL_MAX_DESAT 0.85

/**
 * # Dead Channel (T2, chest, nervous slot, load 4)
 *
 * A pain editor: the nervous slot's other answer, competing with Slipwire.
 * Pain reporting is cut entirely (no pain messages, no soft crit, you stand
 * until hard crit), stamina damage is halved, and damage slowdown never
 * reaches your legs. The cost is information: the only gauge you get is the
 * world quietly desaturating as the meat racks up damage you can't feel.
 * You find out how bad it was afterwards.
 *
 * "You can't tell how bad it's gotten" is enforced rather than implied. While
 * the editor is actually running, the bearer loses every readout of their own
 * condition:
 * - health bar and health doll, through tg's fake_healthy screwy-hud: the
 *   same primitive the Numb quirk uses, and grouped, so wearing both is fine;
 * - the brute and crit damage vignettes, through TRAIT_NO_DAMAGE_OVERLAY and
 *   TRAIT_NOCRITOVERLAY, plus a manual clear for the oxygen one (upstream
 *   applies that overlay with no trait gate);
 * - the felt half of a self-examine, and the limb damage read by "check
 *   yourself for injuries".
 * None of that changes what anyone ELSE sees: examine a Dead Channel bearer
 * and their wounds and injuries read exactly as they would on anyone.
 *
 * All of it lifts the moment the ware stops running, browned out, EMP
 * scrambled, broken or pulled. The same way the colour does.
 *
 * (The design's -25% stun-duration line was dropped at freeze: no clean
 * partial-stun primitive exists in this vintage and we don't fake one.)
 */
/obj/item/organ/cyberimp/cyberware/dead_channel
	name = "\improper Dead Channel pain editor"
	desc = "A signal processor clamped over the pain nerves. You stop feeling injuries entirely, which keeps you upright and moving where anyone else would fold. The catch is that you can't tell how bad it's gotten. The colour draining out of the world is the only gauge you get."
	icon_state = "dead_channel"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_NERVOUS
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 4
	tier = CYBERWARE_TIER_2
	organ_traits = list(TRAIT_ANALGESIA, TRAIT_NOSOFTCRIT)
	/// Our live screen tint, updated as damage mounts.
	var/datum/client_colour/desat_colour
	/// TRUE while the bearer's own damage feedback is actually cut. Only ever
	/// flipped through set_feedback_cut(), which owns every piece of it.
	var/feedback_cut = FALSE
	/// TRUE while the stamina mod and slowdown immunity are applied. Guards
	/// the failing-gated passive hooks against double multiply/divide.
	var/channel_mods_applied = FALSE

/obj/item/organ/cyberimp/cyberware/dead_channel/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	desat_colour = organ_owner.add_client_colour(/datum/client_colour/cyberware_dead_channel, REF(src))
	RegisterSignal(organ_owner, COMSIG_LIVING_HEALTH_UPDATE, PROC_REF(on_health_update))
	RegisterSignal(organ_owner, COMSIG_ATOM_EXAMINE, PROC_REF(on_owner_examined))
	RegisterSignal(organ_owner, COMSIG_CARBON_CHECKING_BODYPART, PROC_REF(on_owner_checks_limb))
	refresh_feedback_cut()
	on_health_update(organ_owner)

// The pain edit itself now rides the failing-gated passive layer (BAL-4):
// while the editor is EMP-scrambled or browned out, TRAIT_ANALGESIA and
// TRAIT_NOSOFTCRIT (through the base hooks), the stamina halving and the
// damage-slowdown immunity all drop, and every injury the bearer racked up
// arrives at once. The readouts were already gated through feedback_cut;
// this makes the protection match what the HUD was claiming.
/obj/item/organ/cyberimp/cyberware/dead_channel/chrome_passives_on(mob/living/carbon/bearer)
	. = ..()
	if(channel_mods_applied || isnull(bearer))
		return
	channel_mods_applied = TRUE
	if(ishuman(bearer))
		var/mob/living/carbon/human/human_bearer = bearer
		human_bearer.physiology.stamina_mod *= CYBERWARE_DEAD_CHANNEL_STAMINA_MULT
	bearer.add_movespeed_mod_immunities(REF(src), /datum/movespeed_modifier/damage_slowdown)

/obj/item/organ/cyberimp/cyberware/dead_channel/chrome_passives_off(mob/living/carbon/bearer)
	. = ..()
	if(!channel_mods_applied)
		return
	channel_mods_applied = FALSE // reset before the validity skip, see Shock Coils
	if(isnull(bearer) || QDELETED(bearer))
		return
	if(ishuman(bearer))
		var/mob/living/carbon/human/human_bearer = bearer
		human_bearer.physiology.stamina_mod /= CYBERWARE_DEAD_CHANNEL_STAMINA_MULT
	bearer.remove_movespeed_mod_immunities(REF(src), /datum/movespeed_modifier/damage_slowdown)

/obj/item/organ/cyberimp/cyberware/dead_channel/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	// Hand the readouts back BEFORE anything else runs. mob_remove() nulls
	// `owner` before calling us, so this is the last moment the teardown still
	// has a mob to give the HUD and the vignettes back to. Get it wrong and
	// the ex-bearer walks away with a health bar permanently pinned to full.
	set_feedback_cut(FALSE, organ_owner)
	UnregisterSignal(organ_owner, list(
		COMSIG_ATOM_EXAMINE,
		COMSIG_CARBON_CHECKING_BODYPART,
		COMSIG_LIVING_HEALTH_UPDATE,
	))
	. = ..()
	// The stamina mod and slowdown immunity come off in chrome_passives_off(),
	// which the component fires from this same removal (COMSIG_ORGAN_REMOVED).
	organ_owner.remove_client_colour(REF(src))
	desat_colour = null

/**
 * The heartbeat behind the cut. updatehealth() covers every case where damage
 * moves, but the ware can go dark (brownout, EMP reboot finishing) while the
 * bearer stands perfectly still and takes no damage at all, this settles the
 * state once a tick regardless. Still called while ORGAN_FAILING, which is
 * exactly when it matters.
 */
/obj/item/organ/cyberimp/cyberware/dead_channel/on_life(seconds_per_tick, times_fired)
	. = ..()
	refresh_feedback_cut()

/// Settles the cut against the ware's live state: running and installed, or not.
/obj/item/organ/cyberimp/cyberware/dead_channel/proc/refresh_feedback_cut()
	set_feedback_cut(owner && !(organ_flags & ORGAN_FAILING), owner)

/**
 * The one place the suppression goes on and off, so every piece of it is
 * added and dropped together.
 *
 * `bearer` is passed rather than read off `owner` because the teardown path
 * runs after mob_remove() has already nulled it. A null bearer never flips
 * the flag: dropping it there would strand the status effect and the traits
 * on a live player with no organ left to take them off again.
 */
/obj/item/organ/cyberimp/cyberware/dead_channel/proc/set_feedback_cut(cutting, mob/living/carbon/bearer)
	cutting = !!cutting
	if(feedback_cut == cutting || !istype(bearer))
		return
	feedback_cut = cutting
	if(cutting)
		bearer.apply_status_effect(/datum/status_effect/grouped/screwy_hud/fake_healthy, REF(src))
		bearer.add_traits(list(TRAIT_NO_DAMAGE_OVERLAY, TRAIT_NOCRITOVERLAY), REF(src))
	else
		bearer.remove_status_effect(/datum/status_effect/grouped/screwy_hud/fake_healthy, REF(src))
		bearer.remove_traits(list(TRAIT_NO_DAMAGE_OVERLAY, TRAIT_NOCRITOVERLAY), REF(src))
	// The traits and the status effect only gate the NEXT redraw, so whatever
	// is on screen right now has to be re-settled by hand. This is the half
	// that matters on the way OUT: without it a bearer who loses the ware
	// mid-vignette keeps the overlay until something else happens to them.
	bearer.update_damage_hud()
	bearer.update_health_hud()
	if(cutting)
		bearer.clear_fullscreen("oxy", 0)

/**
 * Signal proc for [COMSIG_ATOM_EXAMINE] on the bearer: cut the lines that
 * report FELT damage, and only when the examiner is the bearer themselves.
 * Anyone else looking at a Dead Channel bearer reads their wounds and
 * injuries completely normally.
 *
 * The brute and burn severity lines are already gone by the time this runs.
 * Upstream skips those on a self-examine while fake_healthy is up. What is
 * left is the per-wound descriptions and the disabled-limb lines, rebuilt the
 * way carbon/examine.dm built them and removed by value.
 *
 * Left alone on purpose: embedded objects, bleeding, blood-loss pallor and
 * missing limbs. The editor sits on the pain nerves, not on the eyes, a
 * knife in your leg is still a knife you can look down and see.
 */
/obj/item/organ/cyberimp/cyberware/dead_channel/proc/on_owner_examined(mob/living/carbon/source, mob/examiner, list/examine_list)
	SIGNAL_HANDLER
	if(!feedback_cut || examiner != source)
		return
	var/their = source.p_their()
	for(var/obj/item/bodypart/body_part as anything in source.bodyparts)
		for(var/datum/wound/limb_wound as anything in body_part.wounds)
			examine_list -= span_danger(limb_wound.get_examine_description(examiner))
		// Upstream skips limbs disabled BY a wound here, so we must too, or we
		// would try to remove a line that was never printed.
		if(!body_part.bodypart_disabled || HAS_TRAIT(body_part, TRAIT_DISABLED_BY_WOUND))
			continue
		var/damage_text = "limp and lifeless"
		if(body_part.get_damage() >= body_part.max_damage)
			damage_text = (body_part.brute_dam >= body_part.burn_dam) ? body_part.heavy_brute_msg : body_part.heavy_burn_msg
		examine_list -= span_boldwarning("[capitalize(their)] [body_part.plaintext_zone] looks [damage_text]!")

/**
 * Signal proc for [COMSIG_CARBON_CHECKING_BODYPART] on the bearer: the
 * check-yourself-for-injuries pass reads damage the bearer cannot feel, so
 * every limb comes back clean while the editor runs. Fires only on a self
 * check, check_for_injuries() is never called with anyone else as examiner.
 * Same hook tg's fake health-doll hallucination uses, pointed the other way.
 */
/obj/item/organ/cyberimp/cyberware/dead_channel/proc/on_owner_checks_limb(mob/living/carbon/source, obj/item/bodypart/checked_part, list/check_list, list/limb_damage)
	SIGNAL_HANDLER
	if(!feedback_cut)
		return
	limb_damage[BRUTE] = 0
	limb_damage[BURN] = 0

/**
 * Signal proc for [COMSIG_LIVING_HEALTH_UPDATE]: ease the world toward
 * grayscale as damage mounts, settle the cut, and clear the one damage
 * overlay upstream applies with no trait gate. While the ware is browned out
 * or scrambled the editor stops editing and colour comes back, the one time
 * it "fails safe".
 */
/obj/item/organ/cyberimp/cyberware/dead_channel/proc/on_health_update(mob/living/source)
	SIGNAL_HANDLER
	refresh_feedback_cut()
	if(feedback_cut)
		// updatehealth() runs update_damage_hud() and THEN sends this signal,
		// so the oxygen vignette is re-applied and cleared inside one call and
		// never survives to a frame the bearer can see.
		source.clear_fullscreen("oxy", 0)
	if(!desat_colour)
		return
	var/fraction = 0
	if(!(organ_flags & ORGAN_FAILING) && source.maxHealth > 0)
		fraction = clamp(1 - (source.health / source.maxHealth), 0, 1)
	var/desat = fraction * CYBERWARE_DEAD_CHANNEL_MAX_DESAT
	// Rec.709 luma-weighted partial desaturation. Rows are input R/G/B's
	// contribution to output (R, G, B).
	var/sat = 1 - desat
	desat_colour.update_color(list(
		0.213 + 0.787 * sat, 0.213 - 0.213 * sat, 0.213 - 0.213 * sat,
		0.715 - 0.715 * sat, 0.715 + 0.285 * sat, 0.715 - 0.715 * sat,
		0.072 - 0.072 * sat, 0.072 - 0.072 * sat, 0.072 + 0.928 * sat,
	), 0.5 SECONDS)

/datum/client_colour/cyberware_dead_channel
	priority = CLIENT_COLOR_ORGAN_PRIORITY
	color = COLOR_MATRIX_IDENTITY // driven live by the organ

// =========================================================================
// HOPPER PISTONS
// =========================================================================

/// Leap distance in tiles.
#define CYBERWARE_HOPPER_RANGE 4
/// Airtime before the landing thud.
#define CYBERWARE_HOPPER_AIRTIME (0.2 SECONDS)

/**
 * # Hopper Pistons (T2, legs, load 3)
 *
 * Coiled myomer pistons in both calves: leap up to four tiles to any open
 * floor you can see with a clear lane to it, clearing tables, mobs and gaps
 * outright. Walls, windows and shut doors are jumped over by nobody, see
 * [/datum/action/cooldown/cyberware/proc/arc_blocker]. Rung two of the leg
 * ladder, evicts Shock Coils, gets evicted by the Meteor Piledriver.
 * Mechanism follows tg's dash (decoy + move + miss-whoosh) with a
 * click-targeted destination and a hard density check on the landing tile.
 */
/obj/item/organ/cyberimp/cyberware/hopper
	name = "\improper Hopper piston calves"
	desc = "Paired myomer pistons sleeved over both calves. Four tiles of flat jump on demand, over railings, tables and whoever's in the way. Flat is the operative word: they will not put you over a wall."
	icon_state = "hopper"
	zone = BODY_ZONE_L_LEG
	slot = ORGAN_SLOT_CYBERWARE_LEGS
	// Either calf is a valid incision site; see the Shock Coils for the why.
	valid_zones = list(
		BODY_ZONE_L_LEG = ORGAN_SLOT_CYBERWARE_LEGS,
		BODY_ZONE_R_LEG = ORGAN_SLOT_CYBERWARE_LEGS,
	)
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 3
	tier = CYBERWARE_TIER_2
	aug_overlay = "hopper"
	actions_types = list(/datum/action/cooldown/cyberware/hopper_leap)

/datum/action/cooldown/cyberware/hopper_leap
	name = "Piston Leap"
	desc = "Leap up to four tiles over gaps, tables and people, onto any open floor you can see with a clear lane to it. Walls, windows and shut doors stop the jump."
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "act_hopper"
	cooldown_time = 8 SECONDS
	click_to_activate = TRUE

/datum/action/cooldown/cyberware/hopper_leap/Activate(atom/target)
	if(!isliving(owner))
		return FALSE
	var/mob/living/jumper = owner
	var/turf/destination = get_turf(target)
	var/turf/here = get_turf(jumper)
	if(isnull(destination) || isnull(here) || destination == here)
		return FALSE
	if(jumper.buckled || !isturf(jumper.loc))
		jumper.balloon_alert(jumper, "can't jump from here!")
		return FALSE
	if(get_dist(here, destination) > CYBERWARE_HOPPER_RANGE)
		jumper.balloon_alert(jumper, "too far!")
		return FALSE
	if(!can_see(jumper, destination, CYBERWARE_HOPPER_RANGE))
		jumper.balloon_alert(jumper, "no line of sight!")
		return FALSE
	if(destination.is_blocked_turf() || islava(destination) || ischasm(destination))
		jumper.balloon_alert(jumper, "landing blocked!")
		return FALSE
	if(arc_blocker(here, destination))
		jumper.balloon_alert(jumper, "no room for the jump!")
		return FALSE
	StartCooldown()
	playsound(here, 'sound/items/weapons/punchmiss.ogg', 40, TRUE, -1)
	new /obj/effect/temp_visual/decoy/fading/halfsecond(here, jumper)
	jumper.visible_message(
		span_warning("[jumper]'s legs fire like pistons and [jumper.p_they()] vault[jumper.p_s()] into the air!"),
		span_notice("You fire the pistons and leap."),
	)
	animate(jumper, pixel_z = 20, time = CYBERWARE_HOPPER_AIRTIME, flags = ANIMATION_RELATIVE, easing = QUAD_EASING|EASE_OUT)
	addtimer(CALLBACK(src, PROC_REF(land), destination), CYBERWARE_HOPPER_AIRTIME)
	return TRUE

/// Touchdown: re-validate the tile (someone can step in during airtime),
/// settle next to it if it filled up, and thud.
/datum/action/cooldown/cyberware/hopper_leap/proc/land(turf/destination)
	var/mob/living/jumper = owner
	if(QDELETED(jumper))
		return
	animate(jumper, pixel_z = -20, time = 0.1 SECONDS, flags = ANIMATION_RELATIVE)
	var/turf/final = destination
	if(QDELETED(final) || final.is_blocked_turf())
		final = null
		for(var/turf/candidate in shuffle(RANGE_TURFS(1, destination)))
			if(!candidate.is_blocked_turf() && !islava(candidate) && !ischasm(candidate))
				final = candidate
				break
	if(!final)
		jumper.balloon_alert(jumper, "landing fouled!")
		return
	jumper.forceMove(final)
	new /obj/effect/temp_visual/mook_dust(final)
	playsound(final, 'sound/effects/gravhit.ogg', 50, TRUE)

#undef CYBERWARE_DODGE_MOVE_WINDOW
#undef CYBERWARE_DEADEYE_TAG_RANGE
#undef CYBERWARE_DEADEYE_TAG_SHOTS
#undef CYBERWARE_DEADEYE_TAG_DURATION
#undef CYBERWARE_DEADEYE_MARK_FILTER
#undef CYBERWARE_SLIPWIRE_DODGE_CHANCE
#undef CYBERWARE_DEAD_CHANNEL_STAMINA_MULT
#undef CYBERWARE_DEAD_CHANNEL_MAX_DESAT
#undef CYBERWARE_HOPPER_RANGE
#undef CYBERWARE_HOPPER_AIRTIME
