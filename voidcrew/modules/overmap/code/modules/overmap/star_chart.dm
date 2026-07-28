/**
 * # Star Chart
 *
 * A one-use survey slate sold by traders. Used aboard a ship, it charts every
 * static object in one zone band straight onto the helm's navigation readout —
 * the certainty channel for discovery, the bulk alternative to active scanning
 * tile by tile.
 */
/obj/item/disk/star_chart
	name = "star chart"
	desc = "A survey slate preloaded with the coordinates of one region of the system. Use it aboard a ship to chart those contacts onto the navigation readout."
	icon = 'voidcrew/modules/overmap/icons/obj/star_chart.dmi'
	icon_state = "star_chart"
	/// Zone band this chart reveals (a ZONE_* constant). Unset on this base
	/// type, which is only the shared parent - every sold chart is a subtype.
	var/chart_zone_type = null
	/// Human-readable region label for the upload notification. Unset here for
	/// the same reason as chart_zone_type.
	var/zone_label = null

/obj/item/disk/star_chart/attack_self(mob/user)
	if(isnull(chart_zone_type))
		balloon_alert(user, "slate is blank!")
		return
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(user)
	if(!ship)
		balloon_alert(user, "must be aboard a ship!")
		return
	var/charted = ship.chart_zone(chart_zone_type)
	if(charted > 0)
		ship.ship_notify("Star chart uploaded: [charted] new contact[charted > 1 ? "s" : ""] in [zone_label] added to the navigation readout.", "SENSORS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 25)
		to_chat(user, span_notice("You upload [src] to the ship's navigation readout: [charted] new contact[charted > 1 ? "s" : ""] charted."))
	else
		to_chat(user, span_notice("You upload [src], but the navigation readout already covers [zone_label]."))
	qdel(src)

/obj/item/disk/star_chart/green
	name = "star chart (neutral ring)"
	desc = "A survey slate mapping the neutral ring. Use it aboard a ship to chart every station and signal in green-zone space."
	chart_zone_type = ZONE_GREEN
	zone_label = "the neutral ring"

/obj/item/disk/star_chart/yellow
	name = "star chart (contested lanes)"
	desc = "A survey slate mapping the contested lanes. Use it aboard a ship to chart every station and signal in yellow-zone space."
	icon_state = "star_chart_yellow"
	chart_zone_type = ZONE_YELLOW
	zone_label = "the contested lanes"

/obj/item/disk/star_chart/red
	name = "star chart (lawless deep)"
	desc = "A survey slate mapping the lawless deep. Use it aboard a ship to chart every station and signal in red-zone space."
	icon_state = "star_chart_red"
	chart_zone_type = ZONE_RED
	zone_label = "the lawless deep"
