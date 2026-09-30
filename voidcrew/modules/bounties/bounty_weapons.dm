/**
 * # Bounty hunting: real weapons
 *
 * Every bounty NPC fights with a real item: the one shown in its hand. Nothing is spawned for the
 * fight and nothing drops; the numbers come off the item type, read once and kept
 * (bounty_real_weapon()):
 * - in the hand: force, damage type, sharpness, wound bonuses, armour penetration, hitsound and
 *   verbs, put on the mob (apply_melee()). tg's basic mob blow (attack_animal()) passes the mob's
 *   sharpness and wound bonuses to apply_damage(), so a knife cuts and a bat breaks bones as they do
 *   in a player's hand. Bare fists hit like a human's punch;
 * - thrown: its throwforce, the way tg's hitby() applies it (load_thrown());
 * - a gun: the rounds in the magazine it comes with (or the ammunition given), the casing's pellets
 *   and spread, the gun's own spread and projectile multipliers, and the round's damage, damage
 *   type, armour penetration, wounds, sharpness, embedding, speed and range (load()).
 * The NPCs keep their own projectile types, which carry their rules on who they may hit: the
 * round's numbers are copied onto them as they are fired.
 */

/// Every real weapon read so far, by "[item type]|[ammunition type]"
GLOBAL_LIST_EMPTY(bounty_real_weapons)

/// The real weapon `item_type` (null: bare fists), loaded with `ammo_type` if given
/proc/bounty_real_weapon(item_type, ammo_type)
	var/key = "[item_type || "fists"]|[ammo_type]"
	var/datum/bounty_real_weapon/weapon = GLOB.bounty_real_weapons[key]
	if(!weapon)
		weapon = new(item_type, ammo_type)
		GLOB.bounty_real_weapons[key] = weapon
	return weapon

/// What a real item does as a weapon, read off its type
/datum/bounty_real_weapon
	/// The item, or null for bare fists
	var/item_type

	// ----- in the hand, and thrown -----

	/// The hand numbers are read from a copy of the item, made and deleted the first time they're wanted
	var/melee_read = FALSE
	/// Damage of a blow: the item's force, or a punch's roll
	var/force_low = 0
	var/force_high = 0
	var/throwforce = 0
	var/damage_type = BRUTE
	var/sharpness = NONE
	var/wound_bonus = 0
	var/exposed_wound_bonus = 0
	var/armour_penetration = 0
	var/hitsound
	var/list/verbs_continuous
	var/list/verbs_simple

	// ----- as a gun -----

	/// Rounds in a full magazine, tube or cylinder (0: not a gun)
	var/magazine = 0
	/// Projectiles each round fires, and how far each pellet may stray (degrees, full width)
	var/pellets = 1
	var/variance = 0
	/// The gun's own spread (degrees)
	var/gun_spread = 0
	var/fire_sound
	/// The round, a projectile type, with its numbers below (the gun's multipliers included)
	var/round_type
	var/round_name
	var/round_icon
	var/round_icon_state
	var/round_damage = 0
	var/round_stamina = 0
	var/round_damage_type = BRUTE
	var/round_armor_flag = BULLET
	var/round_armour_penetration = 0
	var/round_weak_against_armour = FALSE
	var/round_wound_bonus = 0
	var/round_exposed_wound_bonus = 0
	var/round_sharpness = NONE
	var/round_embed_type
	var/round_shrapnel_type
	var/round_speed
	var/round_range
	var/round_damage_falloff
	var/round_stamina_falloff
	var/round_wound_falloff
	var/round_embed_falloff
	var/round_dismemberment = 0
	var/round_knockdown = 0
	var/round_paralyze = 0
	var/round_stun = 0
	var/round_immobilize = 0
	var/round_hitsound
	var/round_hitsound_wall
	var/round_impact_effect

/datum/bounty_real_weapon/New(item_type, ammo_type)
	. = ..()
	src.item_type = item_type
	if(ispath(item_type, /obj/item/gun/ballistic))
		read_ballistic(item_type, ammo_type)
	else if(ispath(item_type, /obj/item/mecha_parts/mecha_equipment/weapon/ballistic))
		read_mech_weapon(item_type)

/// A ballistic gun: its magazine, its casing and the round, with the gun's multipliers, as tg's ready_proj() applies them
/datum/bounty_real_weapon/proc/read_ballistic(obj/item/gun/ballistic/gun, obj/item/ammo_casing/ammo)
	var/obj/item/ammo_box/magazine/mag = initial(gun.spawn_magazine_type) || initial(gun.accepted_magazine_type)
	if(mag)
		magazine = initial(mag.max_ammo)
		ammo = ammo || initial(mag.ammo_type)
	gun_spread = initial(gun.spread)
	fire_sound = initial(gun.fire_sound)
	if(!ispath(ammo, /obj/item/ammo_casing))
		return
	pellets = max(1, initial(ammo.pellets))
	variance = initial(ammo.variance)
	read_round(initial(ammo.projectile_type), initial(gun.projectile_damage_multiplier), initial(gun.projectile_wound_bonus), initial(gun.projectile_speed_multiplier))

/// An exosuit's gun: its round and its ammunition box
/datum/bounty_real_weapon/proc/read_mech_weapon(obj/item/mecha_parts/mecha_equipment/weapon/ballistic/gun)
	magazine = initial(gun.projectiles)
	variance = initial(gun.variance)
	fire_sound = initial(gun.fire_sound)
	read_round(initial(gun.projectile))

/// The round's numbers: `damage_mult`, `wound_mod` and `speed_mult` are the gun's
/datum/bounty_real_weapon/proc/read_round(obj/projectile/round, damage_mult = 1, wound_mod = 0, speed_mult = 1)
	if(!ispath(round, /obj/projectile))
		return
	round_type = round
	round_name = initial(round.name)
	round_icon = initial(round.icon)
	round_icon_state = initial(round.icon_state)
	round_damage = initial(round.damage) * damage_mult
	round_stamina = initial(round.stamina) * damage_mult
	round_damage_type = initial(round.damage_type)
	round_armor_flag = initial(round.armor_flag)
	round_armour_penetration = initial(round.armour_penetration)
	round_weak_against_armour = initial(round.weak_against_armour)
	round_wound_bonus = initial(round.wound_bonus) + wound_mod
	round_exposed_wound_bonus = initial(round.exposed_wound_bonus) + wound_mod
	round_sharpness = initial(round.sharpness)
	round_embed_type = initial(round.embed_type)
	round_shrapnel_type = initial(round.shrapnel_type)
	round_speed = initial(round.speed) * speed_mult
	round_range = initial(round.range)
	round_damage_falloff = initial(round.damage_falloff_tile)
	round_stamina_falloff = initial(round.stamina_falloff_tile)
	round_wound_falloff = initial(round.wound_falloff_tile)
	round_embed_falloff = initial(round.embed_falloff_tile)
	round_dismemberment = initial(round.dismemberment)
	round_knockdown = initial(round.knockdown)
	round_paralyze = initial(round.paralyze)
	round_stun = initial(round.stun)
	round_immobilize = initial(round.immobilize)
	round_hitsound = initial(round.hitsound)
	round_hitsound_wall = initial(round.hitsound_wall)
	round_impact_effect = initial(round.impact_effect_type)

/**
 * The hand numbers, from a copy of the item made and deleted here (its verbs are lists, and its
 * hitsound is only filled in when it is made). Bare fists are a human's arm: its punch.
 */
/datum/bounty_real_weapon/proc/read_melee()
	if(melee_read)
		return
	melee_read = TRUE
	if(!item_type)
		var/obj/item/bodypart/arm/right/arm = new
		force_low = arm.unarmed_damage_low
		force_high = arm.unarmed_damage_high
		damage_type = arm.attack_type
		sharpness = arm.unarmed_sharpness
		hitsound = arm.unarmed_attack_sound
		verbs_continuous = arm.unarmed_attack_verbs_continuous?.Copy()
		verbs_simple = arm.unarmed_attack_verbs?.Copy()
		qdel(arm)
		return
	if(!ispath(item_type, /obj/item) || ispath(item_type, /obj/item/mecha_parts))
		return
	var/obj/item/thing = new item_type
	force_low = thing.force
	force_high = thing.force
	throwforce = thing.throwforce
	damage_type = thing.damtype
	sharpness = thing.get_sharpness()
	wound_bonus = thing.wound_bonus
	exposed_wound_bonus = thing.exposed_wound_bonus
	armour_penetration = thing.armour_penetration
	hitsound = thing.hitsound || (thing.force ? SFX_SWING_HIT : null)
	verbs_continuous = thing.attack_verb_continuous?.Copy()
	verbs_simple = thing.attack_verb_simple?.Copy()
	qdel(thing)

/// Puts its hand numbers on `fighter`'s own blow. The blow's timing stays the fighter's.
/datum/bounty_real_weapon/proc/apply_melee(mob/living/basic/fighter)
	read_melee()
	fighter.melee_damage_lower = force_low
	fighter.melee_damage_upper = force_high
	fighter.melee_damage_type = damage_type
	fighter.sharpness = sharpness
	fighter.wound_bonus = wound_bonus
	fighter.exposed_wound_bonus = exposed_wound_bonus
	fighter.armour_penetration = armour_penetration
	fighter.attack_sound = hitsound
	pick_verb(fighter)

/// One of its verbs for `fighter`'s next blow, as a player's swing picks one
/datum/bounty_real_weapon/proc/pick_verb(mob/living/basic/fighter)
	read_melee()
	var/count = min(length(verbs_continuous), length(verbs_simple))
	if(!count)
		return
	var/index = rand(1, count)
	fighter.attack_verb_continuous = verbs_continuous[index]
	fighter.attack_verb_simple = verbs_simple[index]

/// Puts its throw on `shot`, a thrown thing flying as one of the NPCs' projectiles: its throwforce, against melee armour
/datum/bounty_real_weapon/proc/load_thrown(obj/projectile/shot)
	read_melee()
	shot.damage = throwforce
	shot.damage_type = damage_type
	shot.armor_flag = MELEE
	shot.armour_penetration = armour_penetration
	shot.sharpness = sharpness
	// tg's hitby() passes no wound bonus for a thrown item
	shot.wound_bonus = 0
	shot.exposed_wound_bonus = 0

/// Puts the round's numbers on `shot`, one of the NPCs' own projectiles, before it flies. FALSE if this is no gun.
/datum/bounty_real_weapon/proc/load(obj/projectile/shot)
	if(!round_type || QDELETED(shot))
		return FALSE
	shot.name = round_name
	shot.icon = round_icon
	shot.icon_state = round_icon_state
	shot.damage = round_damage
	shot.stamina = round_stamina
	shot.damage_type = round_damage_type
	shot.armor_flag = round_armor_flag
	shot.armour_penetration = round_armour_penetration
	shot.weak_against_armour = round_weak_against_armour
	shot.wound_bonus = round_wound_bonus
	shot.exposed_wound_bonus = round_exposed_wound_bonus
	shot.sharpness = round_sharpness
	shot.shrapnel_type = round_shrapnel_type
	shot.embed_type = round_embed_type
	shot.set_embed(round_embed_type)
	shot.speed = round_speed
	shot.range = round_range
	shot.maximum_range = round_range
	shot.damage_falloff_tile = round_damage_falloff
	shot.stamina_falloff_tile = round_stamina_falloff
	shot.wound_falloff_tile = round_wound_falloff
	shot.embed_falloff_tile = round_embed_falloff
	shot.dismemberment = round_dismemberment
	shot.knockdown = round_knockdown
	shot.paralyze = round_paralyze
	shot.stun = round_stun
	shot.immobilize = round_immobilize
	shot.hitsound = round_hitsound
	shot.hitsound_wall = round_hitsound_wall
	shot.impact_effect_type = round_impact_effect
	return TRUE

/**
 * Degrees one projectile of a round strays, by tg's rolls: a pellet (or any round whose casing has
 * spread) by the casing's variance, fire_casing(); a single bullet by the gun's own spread,
 * process_fire(), whose 1.4 is its DUALWIELD_PENALTY_EXTRA_MULTIPLIER.
 */
/datum/bounty_real_weapon/proc/shot_spread()
	if(variance)
		return round((rand() - 0.5) * variance)
	if(gun_spread)
		return round((rand(0, 1) - 0.5) * 1.4 * rand(0, gun_spread))
	return 0

// ===== THROWN BACK =====

/**
 * Throws `victim` up to `tiles` straight away from `thrower`, the way tg throws people
 * (throw_at()), at `speed`. A throw that isn't `gentle` hurts when it ends against a wall, as tg's
 * does. It is cut short before lava, a chasm, open space, empty space or anywhere else unsafe to
 * land, and before it would leave `keep_in` (an area) if one is given. Returns how many tiles it is
 * thrown, or 0.
 */
/proc/bounty_throw_back(atom/thrower, atom/movable/victim, tiles, speed, gentle = FALSE, area/keep_in)
	var/turf/start = get_turf(victim)
	var/throw_dir = get_dir(thrower, victim)
	if(!start || !throw_dir || !isturf(victim.loc) || victim.anchored || tiles <= 0)
		return 0
	var/reach = 0
	var/turf/next = start
	for(var/step in 1 to tiles)
		next = get_step(next, throw_dir)
		if(!next)
			break
		// A wall stops the throw there on its own
		if(next.density)
			reach = step
			break
		if(isspaceturf(next) || isopenspaceturf(next) || isgroundlessturf(next) || islava(next) || ischasm(next))
			break
		if(ismob(victim) && !next.can_cross_safely(victim))
			break
		if(keep_in && get_area(next) != keep_in)
			break
		reach = step
	if(!reach)
		return 0
	var/turf/far = get_edge_target_turf(victim, throw_dir)
	if(!far || !victim.throw_at(far, reach, speed, thrower, gentle = gentle))
		return 0
	return reach
