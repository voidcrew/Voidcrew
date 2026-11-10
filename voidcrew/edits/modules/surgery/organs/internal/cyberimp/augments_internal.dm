// Voidcrew fix to code/modules/surgery/organs/internal/cyberimp/augments_internal.dm.

// tg's cyberimp Destroy() deletes the implant's bodypart overlay before the organ comes out, so
// on_bodypart_remove() finds no overlay to take off and the limb keeps a dead one with no implant
// behind it: every later redraw of that limb runtimes. Chrome deleted inside a body hits it, as a human
// NPC's cyberware (voidcrew/modules/cyberware/, voidcrew/modules/human_npcs/) does when its body is
// deleted. The overlay comes off the limb first.
/obj/item/organ/cyberimp/Destroy()
	if(bodypart_aug && bodypart_owner)
		var/redraw = !QDELETED(bodypart_owner) && !QDELETED(bodypart_owner.owner)
		bodypart_owner.remove_bodypart_overlay(bodypart_aug, update = redraw)
	return ..()
