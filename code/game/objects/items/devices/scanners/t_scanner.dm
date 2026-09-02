/obj/item/t_scanner
	name = "\improper T-ray scanner"
	desc = "A terahertz-ray emitter and scanner used to detect underfloor objects such as cables and pipes."
	custom_price = PAYCHECK_LOWER * 0.7
	icon = 'icons/obj/devices/scanner.dmi'
	icon_state = "t-ray0"
	slot_flags = ITEM_SLOT_BELT
	w_class = WEIGHT_CLASS_SMALL
	inhand_icon_state = "electronic"
	worn_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	custom_materials = list(/datum/material/iron=SMALL_MATERIAL_AMOUNT * 1.5)
	/// Is this T-Ray scanner currently on?
	var/on = FALSE

/obj/item/t_scanner/suicide_act(mob/living/carbon/user)
	user.visible_message(span_suicide("[user] begins to emit terahertz-rays into [user.p_their()] brain with [src]! It looks like [user.p_theyre()] trying to commit suicide!"))
	return TOXLOSS

/obj/item/t_scanner/proc/toggle_on()
	playsound(src, SFX_INDUSTRIAL_SCAN, 20, TRUE, -2, TRUE, FALSE)
	on = !on
	icon_state = copytext_char(icon_state, 1, -1) + "[on]"
	if(on)
		START_PROCESSING(SSobj, src)
	else
		STOP_PROCESSING(SSobj, src)

/obj/item/t_scanner/attack_self(mob/user)
	toggle_on()

/obj/item/t_scanner/cyborg_unequip(mob/user)
	if(!on)
		return
	toggle_on()

/obj/item/t_scanner/process()
	if(!on)
		return PROCESS_KILL
	scan()

/obj/item/t_scanner/proc/scan()
	t_ray_scan(loc)

/**
 * Flashes hidden objects (pipes, cables) to `viewer`.
 *
 * `centre` is where the scan happens; it defaults to the viewer, which is the handheld case.
 * Remote scanners - the ship construction console driving its drone - have to pass the thing
 * doing the looking, or the sweep lands around the operator sat at the console instead of
 * around the camera they are actually watching.
 */
/proc/t_ray_scan(mob/viewer, flick_time = 8, distance = 3, atom/centre)
	if(!ismob(viewer) || !viewer.client)
		return
	if(isnull(centre))
		centre = viewer
	var/list/t_ray_images = list()
	for(var/obj/O in orange(distance, centre) )
		if(HAS_TRAIT(O, TRAIT_T_RAY_VISIBLE))
			var/image/I = new(loc = get_turf(O))
			var/mutable_appearance/MA = new(O)
			MA.alpha = 128
			MA.dir = O.dir
			I.appearance = MA
			t_ray_images += I
	if(t_ray_images.len)
		flick_overlay_global(t_ray_images, list(viewer.client), flick_time)
