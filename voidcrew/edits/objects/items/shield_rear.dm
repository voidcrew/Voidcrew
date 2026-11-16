// A shield held in front of you doesn't stop a shot in the back (owner decision 45). Everyone alike: players and NPCs,
// whatever they know. tg blocks a projectile with a held shield in two places, both reached from the victim's
// bullet_act() (code/modules/mob/living/carbon/human/human_defense.dm): the energy shield's reflection
// (check_reflect() -> IsReflect()) and every shield's block (check_block() -> hit_reaction()). While a shot that comes
// from behind is being resolved, neither works.
//
// "From behind": the shot travels the way its victim faces (its angle, so a ricochet counts from where it really came
// from), the same rear arc as tg's check_behind(). Lying down doesn't count as behind here: the shield still covers.

/mob/living/carbon/human
	/// Set while a projectile that hits this human in the back is being resolved
	var/vc_shot_in_back = FALSE

/// Whether `shot` hits `victim` from behind: it travels the way the victim faces.
/proc/vc_shot_from_behind(mob/living/victim, obj/projectile/shot)
	if(!istype(shot) || isnull(shot.angle))
		return FALSE
	return !!(victim.dir & angle2dir(shot.angle))

/mob/living/carbon/human/bullet_act(obj/projectile/bullet, def_zone, piercing_hit = FALSE)
	var/was_in_back = vc_shot_in_back
	vc_shot_in_back = vc_shot_from_behind(src, bullet)
	. = ..()
	vc_shot_in_back = was_in_back

/obj/item/shield/hit_reaction(mob/living/carbon/human/owner, atom/movable/hitby, attack_text = "the attack", final_block_chance = 0, damage = 0, attack_type = MELEE_ATTACK, damage_type = BRUTE)
	if(attack_type == PROJECTILE_ATTACK && ishuman(owner) && owner.vc_shot_in_back)
		return FALSE
	return ..()

/obj/item/shield/energy/IsReflect(def_zone)
	var/mob/living/carbon/human/holder = loc
	if(ishuman(holder) && holder.vc_shot_in_back)
		return FALSE
	return ..()
