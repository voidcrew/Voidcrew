/**
 * # Field stabiliser
 *
 * A handheld projector that lays a stabilising field over a boulder before its find is freed.
 * Every boulder's rock needs one of eight fields; only the right one holds the find together as
 * the last of the rock comes away. A wrong field looks exactly like a right one. The spectrometer
 * (or an advanced depth scanner) says which field a boulder needs.
 *
 * Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/obj/
 * artifact_stabilizer.dm: the field list (Phoron renamed), picked from a radial instead of an
 * input box. Sprite: Nova tools.dmi anoscanner_borg.
 */

/// The eight fields a boulder's rock may need, with the colour the stabiliser shows for each.
GLOBAL_LIST_INIT(xenoarch_stabilising_fields, list(
	"Diffracted carbon dioxide laser" = "#ff8f6b",
	"Nitrogen tracer field" = "#7fb2ff",
	"Potassium refrigerant cloud" = "#b98bff",
	"Mercury dispersion wave" = "#c9d3dc",
	"Iron wafer conduction field" = "#d08a5c",
	"Calcium binary deoxidizer" = "#f2f0d8",
	"Chlorine diffusion emissions" = "#b6f06a",
	"Plasma saturated field" = "#ff6fd0",
))

/obj/item/excavation/stabiliser
	name = "field stabiliser"
	desc = "An old handheld field projector, built to hold crumbling rock together. Its dial is marked with eight field settings."
	icon_state = "stabiliser"
	inhand_icon_state = "analyzer"
	w_class = WEIGHT_CLASS_NORMAL
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT, /datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT, /datum/material/silver = SMALL_MATERIAL_AMOUNT * 3)
	/// The field it projects, or null before one is dialled in
	var/selected_field

/obj/item/excavation/stabiliser/examine(mob/user)
	. = ..()
	if(selected_field)
		. += "The dial is set to <b>[selected_field]</b>."
	else
		. += "The dial is at rest."

/obj/item/excavation/stabiliser/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	var/list/choices = list()
	for(var/field in GLOB.xenoarch_stabilising_fields)
		var/image/swatch = image('voidcrew/modules/xenoarch/icons/dig_site.dmi', "field")
		swatch.color = GLOB.xenoarch_stabilising_fields[field]
		choices[field] = swatch
	var/picked = show_radial_menu(user, src, choices, require_near = TRUE, tooltips = TRUE)
	if(!picked || !user.is_holding(src) || !(picked in GLOB.xenoarch_stabilising_fields))
		return TRUE
	selected_field = picked
	playsound(src, 'sound/machines/click.ogg', 30, TRUE)
	balloon_alert(user, "set to [lowertext(picked)]")
	update_appearance()
	return TRUE

/obj/item/excavation/stabiliser/update_overlays()
	. = ..()
	if(!selected_field)
		return
	// A small lamp on the dial shows the setting's colour.
	var/mutable_appearance/lamp = mutable_appearance(icon, "stabiliser_lamp")
	lamp.color = GLOB.xenoarch_stabilising_fields[selected_field]
	. += lamp
