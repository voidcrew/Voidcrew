/// Capture this NUMBER on delayed effects, so creator deletion cannot change damage.
/mob/living/proc/get_npc_zone_damage_factor()
	if(npc_zone_applied && is_npc_zone_exempt())
		exempt_npc_zone()
	return npc_zone_damage_factor

/// Raw ability input by default. Set already_scaled for a roll of scaled melee bounds.
/// Delayed effects pass their captured numeric factor instead of retaining a mob.
/proc/npc_zone_damage(raw_damage, source_or_factor, already_scaled = FALSE)
	if(already_scaled)
		return raw_damage
	var/factor = 1
	if(isliving(source_or_factor))
		var/mob/living/source = source_or_factor
		factor = source.get_npc_zone_damage_factor()
	else if(isnum(source_or_factor))
		factor = source_or_factor
	return raw_damage * factor

/// Always pass RAW weapon force/bounds, including when re-equipping the same weapon.
/mob/living/proc/set_npc_zone_melee(raw_lower, raw_upper)
	npc_zone_original_melee_lower = raw_lower
	npc_zone_original_melee_upper = raw_upper
	var/factor = get_npc_zone_damage_factor()
	melee_damage_lower = raw_lower * factor
	melee_damage_upper = raw_upper * factor

/obj/projectile
	/// A reused/reflected projectile retains its first factor, never multiplying twice.
	var/npc_zone_damage_scaled = FALSE
	var/npc_zone_damage_factor = 1

/mob/living/proc/npc_zone_projectile(datum/source, obj/projectile/projectile)
	SIGNAL_HANDLER
	if(projectile.npc_zone_damage_scaled)
		return
	projectile.npc_zone_damage_scaled = TRUE
	projectile.npc_zone_damage_factor = get_npc_zone_damage_factor()
	projectile.damage *= projectile.npc_zone_damage_factor
