/**
 * # The Verdigris: codices
 *
 * Three spells in Ilthuun's own hand, granted by three books that drop with the
 * rest of the hoard (see lich_loot.dm). One per school he fought you in, which
 * is the taxonomy his fight uses, not DM's: `SCHOOL_*` has conjuration and
 * evocation but no illusion, so all three are filed under SCHOOL_NECROMANCY
 * below. That is the honest classification. Every one of them is a lich's work.
 * And it has the correct side effect of getting the caster smitten by an
 * honorbound god's chaplain, which is very funny and entirely deserved.
 *
 * ## Upstream coupling: verified, per spell
 *
 * The base spell cast chain (code/modules/spells/spell.dm) has no antag checks
 * and no resource costs. Garb is demanded in exactly one place,
 * `can_cast_spell()` at spell.dm:186, and only when SPELL_REQUIRES_WIZARD_GARB
 * is set. The base default is
 * `SPELL_REQUIRES_WIZARD_GARB|SPELL_REQUIRES_NO_ANTIMAGIC` (spell.dm:73), so a
 * subtype is garb-locked unless it or an ancestor says otherwise. Checked, in
 * the live code, for each parent used here:
 *
 *  - `/datum/action/cooldown/spell/conjure` (spell_types/conjure/_conjure.dm:1)
 *    and its `/limit_summons` subtype (:71) set no `spell_requirements` at all,
 *    so both inherit the garb-locked default. RELAXED below.
 *  - `/datum/action/cooldown/spell/pointed` (spell_types/pointed/_pointed.dm:10)
 *    and `/datum/action/cooldown/spell/pointed/projectile` (:102) likewise set
 *    no `spell_requirements`. Note that upstream *fireball* is castable by a
 *    plain human only because fireball.dm:15 overrides it itself, the pointed
 *    parents give you nothing. RELAXED below.
 *  - `/datum/action/cooldown/spell` used directly for the mirage: base default,
 *    garb-locked. RELAXED below.
 *
 * In every case the NO_ANTIMAGIC half is kept, so a bible, a tinfoil hat or any
 * other `can_cast_magic()` source shuts these down exactly like it shuts down a
 * wizard. Magic projectiles additionally get `antimagic_flags` propagated onto
 * the bolt by `ready_projectile()` (_pointed.dm:174), which is why the bolt
 * below needs no antimagic plumbing of its own.
 *
 * ## Power calibration
 *
 * Measured against upstream fireball, which already sits in this theme's
 * `loot_prime` at weight 1 as a granter book: fireball is ~65 damage plus an
 * explosion, plus fire, on a 6 second cooldown. The bolt here is 45 to a single
 * target with no structural damage on a 7 second cooldown, and it *heals* the
 * undead it hits. Two thralls at 45 HP for 45 seconds is well under the paper
 * wizard's six permanent stickmen. The mirage deals no damage of its own; it only
 * charges 25 brute to whoever bursts a copy, once per copy, and cannot charge the
 * caster at all. None of this is antag-tier; it is three good verbs on long
 * cooldowns, which is what a four-layer raid should buy.
 */

// =========================================================================
// Local tuning defines, #undef'd at the bottom of the file.
// =========================================================================
/// How long a raised thrall stands before the green goes out of it
#define VERDIGRIS_THRALL_LIFESPAN (45 SECONDS)
/// How many thralls one caster may have up at once
#define VERDIGRIS_THRALL_CAP 2
/// How long the mirages persist
#define VERDIGRIS_MIRAGE_LIFESPAN (20 SECONDS)
/// How many mirages a single casting throws
#define VERDIGRIS_MIRAGE_COUNT 3
/// Brute the burst of a popped mirage costs whoever popped it. Quoted verbatim in
/// the spell's `desc` below, since a 25-brute punish has to be advertised, keep
/// the two in step if this ever moves.
#define VERDIGRIS_MIRAGE_STING 25
/// How far out a casting pulls hunters off the caster and onto the copies
#define VERDIGRIS_MIRAGE_DISTRACT_RANGE 9
/// Burn the bolt lands on impact (applied by the projectile's own `damage`)
#define VERDIGRIS_BOLT_BURN 25
/// Extra toxin the bolt tears out of anything still alive
#define VERDIGRIS_BOLT_ROT 20
/// Damage the bolt mends on an undead target instead of hurting it
#define VERDIGRIS_BOLT_MEND 25

// =========================================================================
// CONJURATION: Raise Thrall
// =========================================================================

/**
 * Raises one short-lived skeleton at the caster's feet, up to
 * VERDIGRIS_THRALL_CAP at a time.
 *
 * Parented on `/datum/action/cooldown/spell/conjure/limit_summons` specifically
 * for its live-count bookkeeping: `post_summon()` registers COMSIG_QDELETING and
 * COMSIG_LIVING_DEATH on each summon and decrements on either (_conjure.dm:85),
 * so the cap is honest whether a thrall is killed or simply times out. The
 * timeout itself is the conjure base's `summon_lifespan` QDEL_IN (_conjure.dm:62).
 * Nothing here has to run a timer.
 *
 * `limit_summons/can_cast_spell()` returns FALSE at the cap with no feedback at
 * all, which reads as a broken button; the override below says so out loud
 * before deferring to the parent.
 */
/datum/action/cooldown/spell/conjure/limit_summons/raise_thrall
	name = "Raise Thrall"
	desc = "Raises a skeleton at your feet to fight for you. It follows you, attacks whatever attacks you, and can be told to stay, heel or go loose. Two at a time, and they do not last long."
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	button_icon_state = "skeleton"
	sound = 'sound/effects/magic/RATTLEMEBONES.ogg'
	school = SCHOOL_NECROMANCY
	cooldown_time = 30 SECONDS
	invocation = "RISE. BE USEFUL. BE BRIEF."
	invocation_type = INVOCATION_SHOUT
	// Relaxed from the conjure chain's inherited garb lock, see the file header.
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC
	spell_max_level = 1

	max_summons = VERDIGRIS_THRALL_CAP
	summon_type = list(/mob/living/basic/skeleton/verdigris_thrall)
	summon_amount = 1
	summon_radius = 1
	summon_lifespan = VERDIGRIS_THRALL_LIFESPAN
	summon_respects_density = TRUE

/datum/action/cooldown/spell/conjure/limit_summons/raise_thrall/can_cast_spell(feedback = TRUE)
	if(number_of_summons >= max_summons)
		if(feedback && owner)
			to_chat(owner, span_warning("You can't hold up any more of the dead at once."))
		return FALSE
	return ..()

/**
 * Binds the fresh thrall to the caster: obedience component, faction, friendship.
 *
 * `befriend()` plus a full faction copy is the same pair this fork's tamed
 * goliaths and wolves use to stop a hostile basic mob attacking its keeper
 * (code/modules/mob/living/basic/lavaland/goliath/goliath.dm,
 * .../icemoon/wolf/wolf.dm), and the same pair the shepherd's crook uses
 * (voidcrew/modules/loot/uniques/occult.dm:674). The obedience component is
 * added only when the pawn actually has an ai_controller, because
 * `/datum/component/obeys_commands/Initialize` returns COMPONENT_INCOMPATIBLE
 * without one (code/datums/components/pet_commands/obeys_commands.dm:26).
 *
 * Ordering note: the component goes on BEFORE `befriend()` on purpose.
 * `follow/start_active` only activates itself from `add_new_friend()`
 * (pet_commands_basic.dm:64), which is reached from the COMSIG_LIVING_BEFRIENDED
 * handler the component registers, so a thrall befriended before it can obey
 * would come up with no standing order and just stand there.
 */
/datum/action/cooldown/spell/conjure/limit_summons/raise_thrall/post_summon(atom/summoned_object, atom/cast_on)
	. = ..()
	var/mob/living/basic/skeleton/thrall = summoned_object
	if(!istype(thrall) || !isliving(owner))
		return
	if(thrall.ai_controller)
		thrall.AddComponent(/datum/component/obeys_commands, list(
			/datum/pet_command/idle,
			/datum/pet_command/free,
			/datum/pet_command/follow/start_active,
			/datum/pet_command/protect_owner,
		))
	// Faction is a REPLACE, not an append, and that is the point. The stock
	// skeleton ships `faction = list(FACTION_SKELETON)`
	// (code/modules/mob/living/basic/ruin_defender/skeleton.dm:20) and the lair's own
	// garrison is FACTION_LICH|FACTION_SKELETON|FACTION_HOSTILE (lich_mob.dm:92), so
	// a thrall that kept FACTION_SKELETON would count as allied to every corpse in
	// the one room you are most likely to raise it in and refuse to swing at them.
	// Copying the owner's list is also what stops it turning on its caster:
	// `/mob/living/Initialize` seeds `REF(src)` into every mob's own faction list
	// (code/modules/mob/living/living.dm:13), so the copy carries REF(owner) and
	// `faction_check_atom` returns TRUE for that pair and for nobody else. The bare
	// Copy() would drop the thrall's own REF along with FACTION_SKELETON, so put it
	// back, anything that befriends the thrall later needs it to resolve.
	thrall.faction = owner.faction.Copy()
	thrall.faction |= REF(thrall)
	thrall.befriend(owner)
	thrall.visible_message(span_warning("[thrall] shoulders its way up out of nothing, green at the joints."))

/// A borrowed servant. Slightly softer than the stock reanimated skeleton
/// (40 HP / 15 melee) because it is free, repeatable and disposable.
/mob/living/basic/skeleton/verdigris_thrall
	name = "verdigris thrall"
	desc = "A skeleton lit green at every joint. Whatever is holding it together, it isn't bone."
	maxHealth = 45
	health = 45
	melee_damage_lower = 12
	melee_damage_upper = 16
	death_message = "sags, and the green goes out of it."
	color = "#a9e0bd"
	light_range = 1.6
	light_power = 0.6
	light_color = LIGHT_COLOR_GREEN
	ai_controller = /datum/ai_controller/basic_controller/verdigris_thrall

/**
 * The thrall's own controller, and the reason a raised thrall now keeps up with
 * you instead of standing where it was raised.
 *
 * It is the stock skeleton controller (skeleton.dm:163) with two differences:
 *
 *  - the pet-command branch is present. Pet commands are run from nowhere else in
 *    the codebase — the branch reads BB_ACTIVE_PET_COMMAND and delegates to the
 *    command datum (code/datums/ai/basic_mobs/pet_commands/pet_command_bt.dm) — so
 *    on the stock skeleton controller the `obeys_commands` component above was inert
 *    and every order handed to a thrall, including its standing follow order, was
 *    silently dropped on the floor. Post-behavior-tree-rewrite it is the
 *    `"override_id": "SUBPLAN_ID_PET_COMMAND"` subtree node, the same wiring
 *    upstream's own `simple_goon` controller uses.
 *  - it is LAST in the selector, which is the opposite of what tamed pets do.
 *    A selector stops at its first non-FAILURE child, so putting the follow order
 *    first would mean a thrall that heels beautifully and never swings at anything.
 *    Running combat first costs nothing when there is no enemy — that branch fails
 *    out when no target exists — so the selector falls through to `follow` exactly
 *    when the thrall has nothing better to do. Fight if there is something to fight,
 *    keep up otherwise.
 *
 * BB_PET_TARGETING_STRATEGY is not optional: `protect_owner/execute_action`
 * resolves it and immediately calls `can_attack()` on the result without a null
 * check (pet_commands_basic.dm:280), so leaving it unset runtimes the first time
 * something hits the caster. `find_food` is dropped from the stock list, a
 * 45-second minion breaking off to look for milk is not a feature.
 */
/datum/ai_controller/basic_controller/verdigris_thrall
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_PET_TARGETING_STRATEGY = /datum/targeting_strategy/basic/not_friends,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
		BB_EMOTE_KEY = "rattles",
		BB_EMOTE_CHANCE = 20,
	)

	ai_movement = /datum/ai_movement/basic_avoidance
	// Old priority order (escape captivity -> emote -> find target -> melee -> pet commands)
	// now lives in verdigris_thrall.bt.json. `idle_behavior = /datum/idle_behavior/idle_random_walk`
	// is carried by the random_walk fallback already inside simple_hostile_combat.
	behavior_tree_json = "voidcrew/modules/lich/verdigris_thrall.bt.json"

/mob/living/basic/skeleton/verdigris_thrall/examine(mob/user)
	. = ..()
	. += span_green("It won't last long. Parts of it are already going transparent.")

// =========================================================================
// DESTRUCTION: Verdigris Bolt
// =========================================================================

/**
 * A slow green bolt. Against the living: VERDIGRIS_BOLT_BURN on impact from the
 * projectile's own `damage`, plus VERDIGRIS_BOLT_ROT toxin torn out on top.
 * Against anything undead: no damage whatsoever and VERDIGRIS_BOLT_MEND healed
 * instead, which is what makes it the companion piece to Raise Thrall rather than
 * a second fireball. See the projectile's `on_hit()` for why the no-damage half
 * has to be arranged before the parent call rather than after it.
 */
/datum/action/cooldown/spell/pointed/projectile/verdigris_bolt
	name = "Verdigris Bolt"
	desc = "Fires a bolt of grave-light at one target. Deals 25 burn and 20 toxin to the living. The undead take no damage from it and are healed 25 instead."
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	// Existing states only: actions_spells.dmi has no green/necro bolt button,
	// and asking track F for one for a rarely-seen button isn't worth the sprite.
	button_icon_state = "arcane_barrage"
	sound = 'sound/effects/magic/magic_missile.ogg'
	school = SCHOOL_NECROMANCY
	cooldown_time = 7 SECONDS
	invocation = "VERDE MORI!"
	invocation_type = INVOCATION_SHOUT
	// Relaxed from the pointed/projectile chain's inherited garb lock (see the)
	// file header. (Upstream fireball only escapes it by overriding this itself.)
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC
	spell_max_level = 1

	active_msg = "Grave-light gathers in your hand."
	deactive_msg = "You let the grave-light go out."
	cast_range = 8
	projectile_type = /obj/projectile/magic/verdigris_bolt

/**
 * Inherits `/obj/projectile/magic`'s antimagic handling wholesale
 * (magic.dm:13, a target that `can_block_magic()` makes the bolt fizzle before
 * it ever hits, from `prehit_pierce()`), and gets its `antimagic_flags` written by
 * the spell's `ready_projectile()`.
 *
 * Sprite note: borrows the existing "necropotence" projectile state and recolors
 * it green, rather than asking track F for a projectile sprite. No behaviour is
 * inherited from `/obj/projectile/magic/necropotence`, that one's soul-tap is
 * deliberately not here.
 */
/obj/projectile/magic/verdigris_bolt
	name = "bolt of verdigris"
	icon_state = "necropotence"
	color = "#7ee8a2"
	damage = VERDIGRIS_BOLT_BURN
	damage_type = BURN
	speed = 1.2
	hitsound = 'sound/effects/magic/mm_hit.ogg'
	light_range = 2
	light_power = 0.8
	light_color = LIGHT_COLOR_GREEN

/**
 * The undead branch has to zero `damage` BEFORE the parent call, and the reason is
 * a piece of upstream ordering that is easy to get backwards. Verified chain:
 *
 *  1. `process_hit_loop()` calls `prehit_pierce()`: where `/obj/projectile/magic`
 *     does its antimagic fizzle, and only afterwards calls
 *     `target.projectile_hit()` (code/modules/projectiles/projectile.dm:532-560).
 *  2. `/atom/bullet_act()` calls `on_hit()` and RETURNS its result
 *     (code/game/atom/atom_act.dm:116). Nothing has been damaged yet.
 *  3. `/mob/living/bullet_act()` takes that return, and only then applies the hit,
 *     via `apply_projectile_effects()` -> `apply_damage(damage = proj.damage, ...)`
 *     (code/modules/mob/living/living_defense.dm:94-132).
 *
 * So the old comment here was wrong: the bolt's 25 BURN had not landed by the time
 * `on_hit` ran, it landed immediately after, which is why the old heal-then-get-hit
 * ordering netted out to roughly zero on a healthy thrall and read to the caster as
 * a plain hit. Zeroing `damage` first suppresses the hit outright, and
 * `is_hostile_projectile()` (projectile.dm:1355) then reads FALSE, which skips the
 * damage and the stun/knockdown effects in the same breath.
 *
 * Antimagic is untouched by this: it resolves in `prehit_pierce()`, two steps
 * earlier, and never looks at `damage`. Pierce is untouched too. This bolt sets no
 * `projectile_piercing` and no `max_pierces`, so it hits exactly one thing and is
 * deleted, and the zeroed instance is never reused.
 */
/obj/projectile/magic/verdigris_bolt/on_hit(atom/target, blocked = 0, pierce_hit)
	var/mob/living/victim = isliving(target) ? target : null
	var/mending = !isnull(victim) && (victim.mob_biotypes & MOB_UNDEAD)
	if(mending)
		damage = 0

	. = ..()

	if(isnull(victim))
		return
	if(mending)
		mend_the_dead(victim)
		return

	victim.adjust_tox_loss(VERDIGRIS_BOLT_ROT, forced = TRUE)
	victim.visible_message(
		span_danger("The green soaks into [victim] and starts to rot [victim.p_them()]."),
		span_userdanger("Something green gets under your skin and starts rotting you."),
	)

/**
 * The mend, split by mob class because the two classes do not agree on what a
 * damage type is.
 *
 * `/mob/living/basic` keeps ONE pool: its `adjust_brute_loss` and `adjust_fire_loss`
 * both funnel into `adjust_health()`, which reads and writes the same `bruteloss`
 * var (code/modules/mob/living/basic/health_adjustment.dm:10-40). Healing brute
 * *and* burn on a skeleton (or on one of our own thralls) would therefore quietly
 * mend twice the advertised amount. Carbons really do split the two, so they get
 * half each and the total is the same either way.
 *
 * `forced = TRUE` because this is a heal and `damage_coeff` is armour: without it
 * an armoured undead like the templar (`damage_coeff = list(BRUTE = 0.5, ...)`,
 * skeleton.dm:89) would be *worse* at accepting the mend than a plain skeleton.
 */
/obj/projectile/magic/verdigris_bolt/proc/mend_the_dead(mob/living/victim)
	if(iscarbon(victim))
		victim.adjust_brute_loss(-VERDIGRIS_BOLT_MEND * 0.5, forced = TRUE)
		victim.adjust_fire_loss(-VERDIGRIS_BOLT_MEND * 0.5, forced = TRUE)
	else
		victim.adjust_brute_loss(-VERDIGRIS_BOLT_MEND, forced = TRUE)
	new /obj/effect/temp_visual/heal(get_turf(victim), COLOR_GREEN)
	victim.visible_message(
		span_green("The grave-light soaks into [victim], and the damage closes over."),
		span_green("The grave-light soaks into you and closes your wounds."),
	)

// =========================================================================
// ILLUSION: Grave Mirage
// =========================================================================

/**
 * Throws up to VERDIGRIS_MIRAGE_COUNT copies of the caster onto the tiles
 * around them and shuffles the caster in among them.
 *
 * Structurally this is `/datum/action/cooldown/spell/pointed/wizard_mimic`
 * (code/modules/mob/living/basic/space_fauna/paper_wizard/paper_abilities.dm:41)
 * turned into a self-cast: shuffled cardinals, a copy on each free step, then
 * `forceMove` the caster onto one more. Two deliberate deviations from that
 * original, both because the original is a boss ability and this is a player's:
 *
 *  - wizard_mimic registers COMSIG_LIVING_HEALTH_UPDATE and deletes every clone
 *    the instant the owner's health changes. On a crew spell that would mean the
 *    mirages evaporate the moment anything grazes you, i.e. immediately, i.e. the
 *    spell would not work. Not copied. The mirages live out their duration.
 *  - the copies are not dense (`density = FALSE`). Boxing yourself into a corner
 *    with your own escape tool is a worse failure than an illusion you can walk
 *    through; targeting and clicking are unaffected by density.
 *
 * The distraction in `misdirect_hunters()` is the load-bearing part and the reason
 * to cast this at all: three stationary props that nothing reacts to are scenery.
 */
/datum/action/cooldown/spell/grave_mirage
	name = "Grave Mirage"
	desc = "Puts three copies of you on the tiles around you and moves you in among them. Anything hunting you switches to a copy instead. A copy bursts on the first hit and deals 25 brute to whoever hit it. They last 20 seconds."
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	// "swap" is the closest existing state: two figures, and you genuinely do
	// end up standing where one of them was.
	button_icon_state = "swap"
	sound = 'sound/effects/magic/mandswap.ogg'
	school = SCHOOL_NECROMANCY
	cooldown_time = 45 SECONDS
	invocation = "which of us is the corpse."
	invocation_type = INVOCATION_WHISPER
	// Relaxed from the base spell default, see the file header.
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC
	spell_max_level = 1
	/// The mirages currently standing, so they can be swept on Remove/Destroy
	var/list/mob/living/basic/verdigris_mirage/mirages = list()

/datum/action/cooldown/spell/grave_mirage/Destroy()
	QDEL_LIST(mirages)
	return ..()

/datum/action/cooldown/spell/grave_mirage/is_valid_target(atom/cast_on)
	return isliving(cast_on) && isturf(cast_on.loc)

/datum/action/cooldown/spell/grave_mirage/cast(atom/cast_on)
	. = ..()
	var/mob/living/caster = cast_on
	if(!isliving(caster))
		return

	// Free steps around the caster, in random order. Mirages take the first few;
	// the caster takes the next one, so the real one isn't always where you left it.
	var/list/turf/free_steps = list()
	for(var/direction in shuffle(GLOB.cardinals))
		var/turf/step_turf = get_step(caster, direction)
		if(!step_turf || step_turf.density || step_turf.is_blocked_turf(exclude_mobs = TRUE))
			continue
		free_steps += step_turf

	if(!length(free_steps))
		to_chat(caster, span_warning("There is nowhere for any of you to stand."))
		return

	// Tracked separately from `mirages` so the retarget below can only ever hand out
	// a copy from THIS casting.
	var/list/mob/living/basic/verdigris_mirage/fresh_copies = list()
	while(length(fresh_copies) < VERDIGRIS_MIRAGE_COUNT && length(free_steps) > 1)
		var/turf/mirage_turf = pick_n_take(free_steps)
		var/mob/living/basic/verdigris_mirage/mirage = new(mirage_turf, caster)
		mirages += mirage
		fresh_copies += mirage
		RegisterSignals(mirage, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH), PROC_REF(on_mirage_lost))
		QDEL_IN(mirage, VERDIGRIS_MIRAGE_LIFESPAN)

	if(!length(fresh_copies))
		to_chat(caster, span_warning("The grave-light gathers, but there's no room for it."))
		return

	caster.forceMove(pick(free_steps))
	new /obj/effect/temp_visual/small_smoke/halfsecond(get_turf(caster))
	caster.visible_message(span_warning("[caster] comes apart into several of [caster.p_them()]self."))

	if(misdirect_hunters(caster, fresh_copies))
		to_chat(caster, span_green("Something that was hunting you goes for one of the copies instead."))

/**
 * The distraction. Anything within VERDIGRIS_MIRAGE_DISTRACT_RANGE that was hunting
 * the caster is moved onto one of the copies. Returns how many were fooled.
 *
 * Both target systems this fork actually contains are handled:
 *
 *  - Modern `/mob/living/basic` mobs keep their victim on the AI blackboard, and the
 *    established way to move one from outside is
 *    `ai_controller.set_blackboard_key(BB_CURRENT_TARGET, thing)` — the
 *    same call the vestige ruins use to steer their own garrisons
 *    (voidcrew/modules/antag_ruins/theme_dragon.dm:403, theme_spider.dm:630).
 *    Crucially the retarget STICKS rather than being overwritten on the next
 *    planning tick: `find_potential_targets/perform()` bails out early and keeps
 *    whatever is already in the key for as long as that target is still legal
 *    (code/datums/ai/basic_mobs/basic_ai_behaviors/targeting.dm:28-30). So a mob
 *    holds onto its mirage until the mirage is popped or leaves its sight.
 *    `cancel_current_plan()` (was `CancelActions()`) is needed as well, or a swing
 *    already queued at the real caster still lands (the same reason
 *    `set_command_active` calls it, code/datums/components/pet_commands/pet_command.dm).
 *  - Legacy `/mob/living/simple_animal/hostile` mobs are still present in this fork
 *    (code/modules/mob/living/simple_animal/hostile/hostile.dm:1) and keep a plain
 *    `target` var. They must be moved with `GiveTarget()`, which does the
 *    LosePatience/GainPatience/Aggro bookkeeping the var alone would skip
 *    (hostile.dm:303).
 *
 * Anything with no ai_controller and no legacy target var (a player, a bot) is
 * left entirely alone. This never touches who a mob is allowed to attack, only who
 * it currently is attacking, so it cannot make something hostile that was not.
 */
/datum/action/cooldown/spell/grave_mirage/proc/misdirect_hunters(mob/living/caster, list/mob/living/decoys)
	if(!length(decoys))
		return 0

	var/fooled = 0
	for(var/mob/living/hunter in view(VERDIGRIS_MIRAGE_DISTRACT_RANGE, caster))
		if(hunter == caster || hunter.stat == DEAD)
			continue
		if(hunter in decoys)
			continue

		var/mob/living/decoy = pick(decoys)
		var/datum/ai_controller/instincts = hunter.ai_controller
		if(instincts)
			var/moved = FALSE
			if(instincts.blackboard[BB_CURRENT_TARGET] == caster)
				instincts.set_blackboard_key(BB_CURRENT_TARGET, decoy)
				moved = TRUE
			if(instincts.blackboard[BB_CURRENT_HUNTING_TARGET] == caster)
				instincts.set_blackboard_key(BB_CURRENT_HUNTING_TARGET, decoy)
				moved = TRUE
			if(moved)
				instincts.cancel_current_plan() // was CancelActions() before the behavior-tree rewrite
				fooled++
			continue

		if(istype(hunter, /mob/living/simple_animal/hostile))
			var/mob/living/simple_animal/hostile/stalker = hunter
			if(stalker.target != caster)
				continue
			stalker.GiveTarget(decoy)
			fooled++

	return fooled

/datum/action/cooldown/spell/grave_mirage/proc/on_mirage_lost(datum/source)
	SIGNAL_HANDLER
	mirages -= source
	UnregisterSignal(source, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH))

/**
 * A copy of whoever cast it, in green, with one hit point and no tell, see
 * `wear_the_face()` for why these are fully opaque, and `on_attacked()` for the
 * cost of finding out which one is which the hard way.
 *
 * Appearance is taken by assigning the caster's `appearance` wholesale, the
 * same one-liner `/obj/effect/temp_visual/decoy` uses
 * (code/game/objects/effects/temporary_visuals/miscellaneous.dm:239), which
 * brings across icon, icon_state, dir and every worn overlay in one go. Note the
 * ordering: `apply_dynamic_human_appearance` is INVOKE_ASYNC and would land
 * *after* Initialize and clobber a copied appearance, so it is only used on the
 * fallback path where no original was passed.
 *
 * Examining one pops it (the paper wizard's copy does the same,
 * paper_wizard.dm:133), except for observers, and except for the caster, who
 * should not be able to destroy their own cover by looking at it.
 */
/mob/living/basic/verdigris_mirage
	name = "mirage"
	desc = "Somebody's double, lit green from the inside."
	icon = 'icons/mob/simple/simple_human.dmi'
	gender = NEUTER
	mob_biotypes = MOB_UNDEAD|MOB_HUMANOID
	maxHealth = 1
	health = 1
	density = FALSE
	melee_damage_lower = 0
	melee_damage_upper = 0
	obj_damage = 0
	basic_mob_flags = DEL_ON_DEATH
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	speak_emote = list("rattles")
	death_message = "comes apart into grave-light."
	/// The base `simple` controller wanders and never fights. A mirage that
	/// stands perfectly still while you move is not a mirage, it is a statue.
	ai_controller = /datum/ai_controller/basic_controller/simple
	/// Who threw us, so they can look at us without popping us
	var/datum/weakref/original_ref
	/// Set the first time we burst on somebody, so the sting can never be paid twice
	var/stung = FALSE

/mob/living/basic/verdigris_mirage/Initialize(mapload, mob/living/original)
	. = ..()
	AddElement(/datum/element/relay_attackers)
	RegisterSignal(src, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_attacked))
	if(original)
		original_ref = WEAKREF(original)
		wear_the_face(original)
	else
		// Only reachable if something spawns one of these without a caster (an
		// admin, a var-edit). Async, so it must not race a copied appearance.
		apply_dynamic_human_appearance(src, species_path = /datum/species/skeleton)

/// Copies the original's whole look, then re-imposes our own ghostly tint on top.
/mob/living/basic/verdigris_mirage/proc/wear_the_face(mob/living/original)
	name = original.name
	appearance = original.appearance
	setDir(original.dir)
	// Fully opaque, and forced rather than inherited. These used to run at alpha 190,
	// which meant the one solid figure in the group was always the real caster, the
	// tell gave the whole spell away. Assigning `appearance` above would also drag
	// across the caster's own alpha, so it is pinned here after the copy.
	alpha = 255
	color = "#8ce8b4"
	set_light(2, 0.6, LIGHT_COLOR_GREEN)

/mob/living/basic/verdigris_mirage/examine(mob/user)
	. = ..()
	if(isobserver(user) || user == original_ref?.resolve())
		. += span_notice("It's a mirage. Grave-light in the shape of somebody who is standing somewhere else.")
		return
	. += span_notice("It's a mirage.")
	new /obj/effect/temp_visual/small_smoke/halfsecond(get_turf(src))
	qdel(src)

/**
 * Hit a mirage and the grave-light in it gets out through you on its way past:
 * VERDIGRIS_MIRAGE_STING brute to whoever swung.
 *
 * Once per copy, guaranteed, and not by relying on the 1 HP to kill us. A swing
 * that lands COMSIG_ATOM_WAS_ATTACKED without dealing damage, a zero-force item, a
 * grab, an unarmed attack a mob's damage roll came up empty on, would leave the
 * mirage standing and let the sting be collected again on the next click. At 10
 * brute that was a nuisance; at 25 it is a real punish, so it gets a real guard.
 * `stung` closes the door and the deferred qdel spends the copy either way.
 *
 * The qdel is deferred by a tick on purpose: this is a SIGNAL_HANDLER firing inside
 * somebody's attack chain, and deleting the thing that chain is still holding a
 * reference to is how you get runtimes downstream of a perfectly good hit.
 *
 * The caster is exempt (they cannot cost themselves 25 brute by clearing their own
 * cover), and so are sibling mirages, which is belt-and-braces. They have 0 melee
 * damage and the `simple` controller does not fight, but cheap.
 */
/mob/living/basic/verdigris_mirage/proc/on_attacked(mob/source, mob/living/attacker, attack_flags)
	SIGNAL_HANDLER
	if(stung)
		return
	if(attack_flags & (ATTACKER_STAMINA_ATTACK|ATTACKER_SHOVING))
		return
	if(!isliving(attacker) || attacker == original_ref?.resolve())
		return
	if(istype(attacker, /mob/living/basic/verdigris_mirage))
		return

	stung = TRUE
	attacker.adjust_brute_loss(VERDIGRIS_MIRAGE_STING)
	to_chat(attacker, span_userdanger("The mirage bursts, spraying green light through your arm!"))
	new /obj/effect/temp_visual/small_smoke/halfsecond(get_turf(src))
	QDEL_IN(src, 0)

// =========================================================================
// THE CODICES
// The three granter books, dropped by drop_lich_hoard() in lich_loot.dm.
//
// Sprite note: these ride existing plain-book states from
// icons/obj/service/library.dmi with a verdigris tint, so they read as a matched
// set of three without asking track F for book art. `/obj/item/book/granter`
// handles all the reading, page-turn and use-count machinery
// (code/game/objects/items/granters/_granters.dm:26); the spell subtype adds the
// recharge hook and the "you already know this" check
// (code/game/objects/items/granters/magic/_spell_granter.dm:32).
//
// Known upstream interaction, not worked around: `granter/action/spell/random`
// (already in this theme's loot_prime at weight 1) picks from
// `subtypesof(/obj/item/book/granter/action/spell)`, and `true_random` picks
// from all non-blacklisted spell schools. These three are therefore in both
// pools. The odds are slim and "the random spellbook turned out to be lich work"
// is a fine outcome, so the upstream static blacklists are left alone.
// =========================================================================

/obj/item/book/granter/action/spell/raise_thrall
	name = "codex of borrowed hands"
	desc = "A slim book bound in cracked green leather. It is very thorough about how to make a skeleton do what it is told."
	icon_state = "book3"
	color = "#77c9a0"
	granted_action = /datum/action/cooldown/spell/conjure/limit_summons/raise_thrall
	action_name = "raise thrall"
	remarks = list(
		"It keeps saying 'ask' and then correcting itself to 'tell'...",
		"So they only need to be ABOUT the right shape. Good...",
		"Two at a time. It is very firm about two at a time...",
		"Apparently they resent it. Not for long, though...",
		"There's a whole page on what to do when it turns around...",
		"'The dead don't argue. Nobody has ever asked them to.'",
	)

/obj/item/book/granter/action/spell/raise_thrall/recoil(mob/living/user)
	. = ..()
	user.visible_message(span_warning("Something under [user]'s feet tries to stand up, thinks better of it, and settles."))
	// upstream deleted RATTLEMEBONES2.ogg; RATTLEMEBONES.ogg is the only surviving variant
	playsound(user, 'sound/effects/magic/RATTLEMEBONES.ogg', 50, TRUE)

/obj/item/book/granter/action/spell/verdigris_bolt
	name = "codex of the working green"
	desc = "A green book about rot magic. Someone has argued with the author in the margins on every single page."
	icon_state = "book5"
	color = "#77c9a0"
	granted_action = /datum/action/cooldown/spell/pointed/projectile/verdigris_bolt
	action_name = "verdigris bolt"
	remarks = list(
		"Point. Say it. Don't hold it. Definitely don't hold it...",
		"It says the bolt is 'polite to its own'. What does that mean...",
		"Oh. It means it heals skeletons. That's going to come up...",
		"Why is the diagram of a hand labelled 'yours, afterward'...",
		"'Rot is just slow work, and I have plenty of time.'",
		"My fingers have gone green and I don't think that's the ink...",
	)

/obj/item/book/granter/action/spell/verdigris_bolt/recoil(mob/living/user)
	. = ..()
	user.visible_message(span_warning("[src] coughs out a wash of green, and the air around [user] starts to smell like wet soil."))
	user.adjust_tox_loss(15, forced = TRUE)

/obj/item/book/granter/action/spell/grave_mirage
	name = "codex of the fourth corpse"
	desc = "A green book with four identical figures inked on the cover. Three of them are labelled. The fourth has been scratched out hard enough to tear the page."
	icon_state = "book7"
	color = "#77c9a0"
	granted_action = /datum/action/cooldown/spell/grave_mirage
	action_name = "grave mirage"
	remarks = list(
		"The trick isn't making the copies. The trick is not flinching...",
		"'Stand where they expect a corpse and they'll look for you somewhere else.'",
		"There's a note here about your own side hitting you by mistake...",
		"Apparently people can tell if they look properly. So don't let them...",
		"Four figures on the cover, three labels. I don't like that...",
		"It's very insistent that you don't point out which one you are...",
	)

/obj/item/book/granter/action/spell/grave_mirage/recoil(mob/living/user)
	. = ..()
	user.visible_message(span_warning("For a moment there are two of [user], and neither of them looks pleased about it."))
	new /obj/effect/temp_visual/decoy/fading/halfsecond(get_turf(user), user)

#undef VERDIGRIS_THRALL_LIFESPAN
#undef VERDIGRIS_THRALL_CAP
#undef VERDIGRIS_MIRAGE_LIFESPAN
#undef VERDIGRIS_MIRAGE_COUNT
#undef VERDIGRIS_MIRAGE_STING
#undef VERDIGRIS_MIRAGE_DISTRACT_RANGE
#undef VERDIGRIS_BOLT_BURN
#undef VERDIGRIS_BOLT_ROT
#undef VERDIGRIS_BOLT_MEND
