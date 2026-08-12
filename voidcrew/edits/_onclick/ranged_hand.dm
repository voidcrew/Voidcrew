/**
 * # Bare-handed clicks past arm's reach
 *
 * `attack_hand()` only ever runs when the clicker is adjacent. Past that the
 * click chain calls [/mob/proc/RangedAttack] on the *clicker*, so a target atom
 * has no hook of its own for an empty-handed click, items get
 * `ranged_interact_with_atom()`, bare hands get nothing.
 *
 * This adds the missing half. An atom that wants to be usable from a couple of
 * tiles away (the outpost traders, who stand behind a counter) overrides
 * `ranged_attack_hand()` and returns TRUE once it has handled the click.
 *
 * Range is the implementer's business, not this hook's: RangedAttack fires for a
 * click anywhere on screen, so every override has to check the distance itself.
 */
/atom/proc/ranged_attack_hand(mob/living/user, list/modifiers)
	return FALSE

/mob/living/RangedAttack(atom/target, modifiers)
	. = ..()
	if(.)
		return
	// Hands out at range is violence, not business. Same split attack_hand makes
	if(combat_mode)
		return FALSE
	return target.ranged_attack_hand(src, modifiers)
