// A limp slows an AI-driven body the way it slows a player.
//
// tg's limp (/datum/status_effect/limp, wound_effects.dm) adds its delay to client.move_delay, so a body with
// no client never limped: a human NPC with a broken or slagged leg walked at full speed. Here a body moved by
// its AI takes the same per-step roll, and a limping step holds its next step back by the same delay, through
// a movespeed modifier its controller reads (basic controllers track cached_multiplicative_slowdown).

/datum/movespeed_modifier/npc_limp
	blacklisted_movetypes = (FLYING|FLOATING)
	variable = TRUE

/datum/status_effect/limp/check_step(mob/whocares, OldLoc, Dir, forced)
	. = ..()
	if(owner.client || !owner.ai_controller)
		return
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/npc_limp)
	if(owner.body_position == LYING_DOWN || !owner.has_gravity() || (owner.movement_type & (FLYING|FLOATING)) || forced || owner.buckled)
		return
	var/determined_mod = owner.has_status_effect(/datum/status_effect/determined) ? 0.5 : 1
	if(SEND_SIGNAL(owner, COMSIG_CARBON_LIMPING) & COMPONENT_CANCEL_LIMP)
		return
	// tg's ..() returns before its roll for a body with no client, so the legs take turns here
	var/stepped_left = next_leg == left
	next_leg = stepped_left ? right : left
	var/chance = stepped_left ? limp_chance_left : limp_chance_right
	var/slowdown = stepped_left ? slowdown_left : slowdown_right
	if(slowdown > 0 && prob(chance * determined_mod))
		owner.add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/npc_limp, multiplicative_slowdown = slowdown * determined_mod)

/datum/status_effect/limp/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/npc_limp)
	return ..()
