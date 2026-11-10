/**
 * Who may use the Widowline's own moves: the aimed sever, the crossing cut and the garrote.
 *
 * Players can. Human NPCs can't yet: the owner wants bounty criminals to use them later, and this is the one
 * place that opens them, for example `return wielder.client || wielder.npc_rank >= HUMAN_NPC_RANK_BOSS`
 * for bosses only. Everything else a wire does (its damage, the cleave and through-cut, clean cuts, blood on
 * the wire, tg's own dismemberment drawn clean) belongs to the weapon and works for any wielder, as it did
 * before these moves existed.
 *
 * Each move also has an entry point that needs no mouse and no target doll, for an AI to call once this
 * lets it: wire_aimed_swing() (the aimed sever), wire_crossing_swing() (the crossing cut) and
 * wire_start_garrote() (the garrote, wire_garrote.dm). Each still asks this proc first.
 */
/proc/hv_wire_moves_allowed(mob/living/wielder)
	if(!isliving(wielder))
		return FALSE
	if(istype(wielder, /mob/living/carbon/human/npc))
		return !!wielder.client
	return TRUE

/**
 * An aimed swing at `victim`'s `zone`, as a player's click with that zone on the target doll: the wire's cut,
 * and the sever if that arm or leg is hurt enough. Where it lands is tg's aim roll, as for anyone. Never starts
 * a garrote. Returns TRUE if it swung.
 */
/obj/item/melee/cyberware_monowire/proc/wire_aimed_swing(mob/living/user, mob/living/victim, zone)
	if(!isliving(user) || !isliving(victim) || !user.is_holding(src) || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED))
		return FALSE
	if(!user.CanReach(victim, src))
		return FALSE
	if(user.get_active_held_item() != src)
		user.swap_hand(user.get_held_index_of_item(src), silent = TRUE)
	var/old_zone = user.zone_selected
	var/old_combat_mode = user.combat_mode
	user.zone_selected = zone
	user.set_combat_mode(TRUE)
	garrote_blow = TRUE
	melee_attack_chain(user, victim)
	if(!QDELETED(src))
		garrote_blow = FALSE
	if(!QDELETED(user))
		user.zone_selected = old_zone
		user.set_combat_mode(old_combat_mode)
		user.changeNext_move(CLICK_CD_MELEE)
	return TRUE

/// The crossing cut on demand: with a wire out in each hand, this aimed swing crosses both through `victim` if it
/// lands, whatever the count. Returns TRUE if it swung as a crossing cut.
/obj/item/melee/cyberware_monowire/proc/wire_crossing_swing(mob/living/user, mob/living/victim, zone = BODY_ZONE_CHEST)
	if(!hv_wire_moves_allowed(user) || wire_count_held(user) < 2)
		return FALSE
	force_cross = TRUE
	. = wire_aimed_swing(user, victim, zone)
	if(!QDELETED(src))
		force_cross = FALSE
