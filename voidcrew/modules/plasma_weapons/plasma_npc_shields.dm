// Plasma bolts on shields that block before the hit lands.
//
// tg's held-shield block runs inside the hit, so the bolt's own impact shows the splash and coat (plasma_effects.dm).
// The Phalanx buckler (loot/uniques/armory.dm), carried raised by the Juggernaut bounty boss, stops shots earlier, on
// the protected body's COMSIG_PROJECTILE_PREHIT, and the bolt never reaches on_hit(). Here a bolt it stops on its
// wielder bursts on it the same way. One it stops on the ally behind the wielder just goes out.

/obj/item/shield/riot/phalanx_buckler/try_block_projectile(mob/living/protected_mob, obj/projectile/incoming)
	. = ..()
	if(!(. & PROJECTILE_INTERRUPT_HIT) || !istype(incoming, /obj/projectile/energy/plasma_bolt))
		return
	if(protected_mob != wielder || !ishuman(wielder) || !(src in wielder.held_items))
		return
	var/obj/projectile/energy/plasma_bolt/bolt = incoming
	bolt.blocked_sound_for(src)
	bolt.plasma_impact_visuals(wielder, 100)
