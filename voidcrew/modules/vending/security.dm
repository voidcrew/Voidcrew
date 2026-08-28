/obj/machinery/vending/security/marine
	name = "\improper marine vendor"
	desc = "A marine equipment vendor."
	product_ads = "Please insert your marine voucher in the bottom slot."
	icon = 'voidcrew/icons/obj/vending2.dmi'
	icon_state = "syndicate-marine"
	icon_deny = "syndicate-marine-deny"
	light_mask = "syndicate-marine-mask"
	icon_vend = "syndicate-marine-vend"
	req_access = list(ACCESS_SYNDICATE)
	products = list(
		/obj/item/restraints/handcuffs = 3,
		/obj/item/assembly/flash/handheld = 2,
		/obj/item/flashlight/seclite = 2,
		/obj/item/ammo_box/magazine/m9mm = 3,
		/obj/item/ammo_box/magazine/m10mm = 3,
		/obj/item/ammo_box/magazine/smgm45 = 3,
		/obj/item/ammo_box/magazine/sniper_rounds = 3,
//		/obj/item/ammo_box/magazine/m556 = 2,
		/obj/item/ammo_box/magazine/m12g = 3,
		/obj/item/grenade/c4 = 1,
		/obj/item/grenade/frag = 1,
		/obj/item/melee/energy/sword/saber/red = 1,
		)
	contraband = list()
	premium = list()
	var/voucher_items = list(
		"M-90gl Carbine" = /obj/item/gun/ballistic/automatic/m90/unrestricted,
		"sniper rifle" = /obj/item/gun/ballistic/rifle/sniper_rifle,
		"C-20r SMG" = /obj/item/gun/ballistic/automatic/c20r/unrestricted,
		"Bulldog Shotgun" = /obj/item/gun/ballistic/shotgun/bulldog/unrestricted)

/obj/machinery/vending/security/marine/solgov
	icon_state = "solgov-marine"
	icon_deny = "solgov-marine-deny"
	light_mask = "solgov-marine-mask"
	icon_vend = "solgov-marine-vend"
	req_access = list(ACCESS_SECURITY)
	products = list(
		/obj/item/restraints/handcuffs = 10,
		/obj/item/assembly/flash/handheld = 10,
		/obj/item/flashlight/seclite = 10,
		/obj/item/reagent_containers/hypospray/combat = 1,
		/*
		/obj/item/ammo_box/magazine/rifle47x33mm = 5,
		/obj/item/ammo_box/magazine/pistol556mm = 10,
		*/
		/obj/item/screwdriver/nuke = 5,
		/obj/item/grenade/c4 = 5,
		/obj/item/grenade/frag = 5,
		/obj/item/grenade/flashbang = 5,
		/obj/item/grenade/barrier = 10,
		/obj/item/melee/energy/sword/saber/blue = 1,
		)
	voucher_items = list(
		"Tactical Energy Gun" = /obj/item/gun/energy/e_gun/stun,
		/*
		"SGV \"Solar\" Assault Rifle" = /obj/item/gun/ballistic/automatic/solar,
		"TGV \"Edison\" Energy Rifle" = /obj/item/gun/energy/laser/terra,*/
		"Inferno Pistol" = /obj/item/gun/energy/laser/thermal/inferno,
		"Cryo Pistol" = /obj/item/gun/energy/laser/thermal/cryo
		)

// Was an attackby() override. Upstream moved the vendor's insert/restock handling out of
// /obj/machinery/vending/attackby and into /obj/machinery/vending/item_interaction
// (code/modules/vending/vendor/interaction.dm), which base_item_interaction runs BEFORE
// attackby. That proc's last branch fires for anyone who passes compartmentLoadAccessCheck()
// with combat mode off - which is exactly the marine who is holding the voucher - and
// returns loadingAttempt() ? SUCCESS : FAILURE. A voucher is in no product list, so
// canLoadItem() refuses it with "[src] does not accept [voucher]!" and returns FAILURE,
// which is ITEM_INTERACT_BLOCKING: the chain stops there and attackby never runs, so the
// redemption menu never opens. Latent today - nothing in the tree spawns /obj/item/gun_voucher
// (the vendors are mapped, the vouchers are not), so this has never been seen in a round -
// but it is the same break, and it fixes itself the same way: catch the voucher in the same
// hook, ahead of the parent.
//
// Click trace, clicking the vendor with a voucher: base_item_interaction -> (voucher has no
// tool_behaviour, tool_act no-ops) -> item_interaction -> HERE -> radial menu -> gun spawned,
// voucher consumed, ITEM_INTERACT_SUCCESS, no bash. Right-click lands here too
// (item_interaction_secondary defaults to item_interaction). Every other item falls to ..()
// and restocks/loads exactly as upstream intends.
/obj/machinery/vending/security/marine/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/gun_voucher))
		RedeemVoucher(tool, user)
		return ITEM_INTERACT_SUCCESS
	return ..()

/obj/machinery/vending/security/marine/proc/RedeemVoucher(obj/item/gun_voucher/voucher, mob/redeemer)
	var/selection = show_radial_menu(redeemer, src, voucher_items, require_near = TRUE, tooltips = TRUE)
	if(!selection || !Adjacent(redeemer) || QDELETED(voucher) || voucher.loc != redeemer)
		return
	if(voucher_items[selection])
		var/drop_location = drop_location()
		var/obj/selected_item = voucher_items[selection]
		new selected_item(drop_location)

	SSblackbox.record_feedback("tally", "gun_voucher_redeemed", 1, selection)
	qdel(voucher)


/obj/item/gun_voucher
	name = "security weapon voucher"
	desc = "A token used to redeem guns from the SecTech vendor."
	icon = 'voidcrew/icons/obj/vending2.dmi'
	icon_state = "sec-voucher"
	w_class = WEIGHT_CLASS_TINY

/obj/item/gun_voucher/solgov
	name = "solgov weapon voucher"
	desc = "A token used to redeem equipment from your nearest marine vendor."
	icon_state = "solgov-voucher"

/obj/item/gun_voucher/syndicate
	name = "syndicate weapon voucher"
	desc = "A token used to redeem equipment from your nearest marine vendor."
	icon_state = "syndie-voucher"
