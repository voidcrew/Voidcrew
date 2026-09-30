// Upstream counts every installed modkit that is a subtype of the one being
// installed or removed, and subtracts that one modkit's modifier for each. Mixing
// cooldown decrease kits with a rapid repeater (a /cooldown subtype) therefore
// dropped the other kits: adding a repeater reset the cooldown to base + repeater,
// and adding or removing a decrease kit counted the repeater as another decrease.
// Sum each installed cooldown kit's own modifier instead.
/obj/item/borg/upgrade/modkit/cooldown/get_recharge_time(obj/item/gun/energy/recharge/kinetic_accelerator/KA)
	var/new_recharge_time = initial(KA.recharge_time)
	for(var/obj/item/borg/upgrade/modkit/cooldown/cooldown_kit in KA.modkits)
		new_recharge_time -= cooldown_kit.modifier
	return new_recharge_time
