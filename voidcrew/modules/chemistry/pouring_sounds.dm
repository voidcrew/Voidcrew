/*
 * Pour sounds that vary with how much you actually poured, ported from
 * monkestation, plus a rare "sparkle" alternate.
 *
 * Upstream cups play a single generic SFX_LIQUID_POUR for every transfer; the
 * call sites in cups/_cup.dm now route through after_pour() instead.
 *
 * Monkestation defines the cup sound table but never calls the cup's
 * after_pour() anywhere - only the dropper's. The cup wiring here is ours.
 *
 * The 2026 upstream merge pulled the cup transfer bodies up into
 * /obj/item/reagent_containers/try_refill() and try_drain(), so the hook is declared on the
 * base container (playing upstream's generic sound) and overridden by the two types that
 * have a sound table of their own.
 */

/// Sound for a completed transfer of [trans] units into [transed_to]. Overridden by the
/// container types that scale their pour sound to the amount.
/obj/item/reagent_containers/proc/after_pour(trans, atom/transed_to, mob/user)
	playsound(get_turf(transed_to || src), SFX_LIQUID_POUR, 50, TRUE)

/obj/item/reagent_containers/cup
	var/static/list/pouring_sounds_categorized = list(
		"0_10" = list(
			'sound/chemistry/transfer/beakerpour_0-10-1.ogg',
			'sound/chemistry/transfer/beakerpour_0-10-2.ogg',
			'sound/chemistry/transfer/beakerpour_0-10-3.ogg',
			'sound/chemistry/transfer/beakerpour_0-10-4.ogg',
			'sound/chemistry/transfer/beakerpour_0-10-5.ogg',
			'sound/chemistry/transfer/beakerpour_0-10-6.ogg',
		),
		"10_25" = list(
			'sound/chemistry/transfer/beakerpour_10-25-1.ogg',
			'sound/chemistry/transfer/beakerpour_10-25-2.ogg',
			'sound/chemistry/transfer/beakerpour_10-25-3.ogg',
			'sound/chemistry/transfer/beakerpour_10-25-5.ogg',
			'sound/chemistry/transfer/beakerpour_10-25-6.ogg',
		),
		"25_50" = list(
			'sound/chemistry/transfer/beakerpour_25-50-1.ogg',
			'sound/chemistry/transfer/beakerpour_25-50-2.ogg',
			'sound/chemistry/transfer/beakerpour_25-50-3.ogg',
		),
		"50_inf" = list(
			'sound/chemistry/transfer/beakerpour_50-inf-1.ogg',
			'sound/chemistry/transfer/beakerpour_50-inf-2.ogg',
			'sound/chemistry/transfer/beakerpour_50-inf-3.ogg',
			'sound/chemistry/transfer/beakerpour_50-inf-4.ogg',
			'sound/chemistry/transfer/beakerpour_50-inf-5.ogg',
		),
	)
	var/static/list/rare_pouring_sound = list(
		"0_10" = 'sound/chemistry/transfer/beakerpour_0-10-sparkle.ogg',
		"10_25" = 'sound/chemistry/transfer/beakerpour_10-25-sparkle.ogg',
		"25_50" = 'sound/chemistry/transfer/beakerpour_25-50-sparkle.ogg',
		"50_inf" = 'sound/chemistry/transfer/beakerpour_50-inf-sparkle.ogg',
	)

/// Plays a pour sound scaled to the amount transferred. Pass the source turf to
/// play from, since a transfer can empty us into something across the tile.
/obj/item/reagent_containers/cup/proc/after_pour(trans, atom/transed_to, mob/user)
	playsound(get_turf(transed_to || src), get_pouring_sound(trans), 60, TRUE, use_reverb = TRUE)

/obj/item/reagent_containers/cup/proc/get_pouring_sound(trans)
	var/pour_amount = "0_10"
	if(trans >= 50)
		pour_amount = "50_inf"
	else if(trans >= 25)
		pour_amount = "25_50"
	else if(trans >= 10)
		pour_amount = "10_25"

	return prob(1) ? rare_pouring_sound[pour_amount] : pick(pouring_sounds_categorized[pour_amount])

/obj/item/reagent_containers/dropper
	var/static/list/dropper_sounds = list(
		'sound/chemistry/transfer/dropper1.ogg',
		'sound/chemistry/transfer/dropper2.ogg',
	)

/obj/item/reagent_containers/dropper/proc/after_pour(trans, atom/transed_to, mob/user)
	playsound(get_turf(src), pick(dropper_sounds), 60, TRUE, use_reverb = TRUE)
