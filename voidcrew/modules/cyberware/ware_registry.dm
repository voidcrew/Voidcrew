/// Remote access to claim management; authority still belongs to the current bearer.
/obj/item/organ/cyberimp/cyberware/registry_uplink
	name = "\improper Registry uplink"
	desc = "A bluespace neural interface to Colonial Registry services. Brings authorized outpost management within reach from anywhere."
	icon_state = "rigger"
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_CYBERWARE_REGISTRY
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 2
	tier = CYBERWARE_TIER_2
	actions_types = list(/datum/action/cooldown/cyberware/outpost_management)
	var/list/datum/player_outpost_management_ui/management_panels = list()

/obj/item/organ/cyberimp/cyberware/registry_uplink/Destroy()
	close_management_panels()
	return ..()

/obj/item/organ/cyberimp/cyberware/registry_uplink/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	close_management_panels()
	return ..()

/obj/item/organ/cyberimp/cyberware/registry_uplink/chrome_passives_off(mob/living/carbon/bearer)
	. = ..()
	close_management_panels()

/obj/item/organ/cyberimp/cyberware/registry_uplink/proc/close_management_panels()
	var/list/closing_panels = management_panels
	management_panels = list()
	QDEL_LIST(closing_panels)

/// No distance, docking, zone or console-power requirement for the implanted uplink.
/obj/item/organ/cyberimp/cyberware/registry_uplink/proc/can_manage_outpost(mob/living/user, obj/structure/overmap/dynamic/player_outpost/home)
	if(QDELETED(src) || QDELETED(user) || owner != user || user.stat != CONSCIOUS || (organ_flags & ORGAN_FAILING))
		return FALSE
	var/datum/component/cyberware/chrome = GetComponent(/datum/component/cyberware)
	if(!chrome || chrome.emp_down || chrome.browned_out)
		return FALSE
	return !QDELETED(home) && home.is_current_management_user(user)

/obj/item/organ/cyberimp/cyberware/registry_uplink/proc/get_management_panel(mob/living/user, obj/structure/overmap/dynamic/player_outpost/home)
	if(!can_manage_outpost(user, home))
		return null
	for(var/datum/player_outpost_management_ui/panel as anything in management_panels.Copy())
		if(QDELETED(panel))
			management_panels -= panel
			continue
		if(panel.manager == user && panel.outpost == home)
			return panel
	var/datum/player_outpost_management_ui/new_panel = new(home, user, null, src)
	return new_panel

/datum/action/cooldown/cyberware/outpost_management
	name = "Outpost Management"
	desc = "Access authorized outpost management through your Registry uplink."
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "rigger"
	cooldown_time = 0 SECONDS

/datum/action/cooldown/cyberware/outpost_management/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return
	var/obj/item/organ/cyberimp/cyberware/registry_uplink/uplink = organ
	if(!istype(uplink) || uplink.owner != owner)
		return FALSE
	for(var/obj/structure/overmap/dynamic/player_outpost/home as anything in GLOB.player_outposts)
		if(uplink.can_manage_outpost(owner, home))
			return TRUE
	if(feedback)
		owner.balloon_alert(owner, "no authorized outposts")
	return FALSE

/datum/action/cooldown/cyberware/outpost_management/Activate(atom/target)
	var/obj/item/organ/cyberimp/cyberware/registry_uplink/uplink = organ
	if(!istype(uplink))
		return FALSE
	var/list/options = list()
	for(var/obj/structure/overmap/dynamic/player_outpost/home as anything in GLOB.player_outposts)
		if(uplink.can_manage_outpost(owner, home))
			options["[length(options) + 1]. [home.name]"] = home
	if(!length(options))
		return FALSE
	var/selection = length(options) == 1 ? options[1] : tgui_input_list(owner, "Select outpost", name, options)
	if(QDELETED(src) || QDELETED(uplink))
		return FALSE
	var/obj/structure/overmap/dynamic/player_outpost/selected_home = options[selection]
	var/datum/player_outpost_management_ui/panel = uplink.get_management_panel(owner, selected_home)
	if(!panel)
		return FALSE
	panel.ui_interact(owner)
	return TRUE
