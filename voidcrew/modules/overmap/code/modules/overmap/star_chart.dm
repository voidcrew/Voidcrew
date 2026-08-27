/**
 * # Star Chart
 *
 * A one-use survey slate sold by traders. Inserted into a ship's helm console,
 * it charts every object in one zone band straight onto the helm's navigation
 * readout, the certainty channel for discovery, the bulk alternative to
 * active scanning tile by tile.
 *
 * Deliberately wider than a scan: this is the only way to learn where the storms
 * and nebulas are without flying into them, since the ship's own sensors can't
 * record either (see chart_zone in ship_sensors.dm).
 */
/obj/item/disk/star_chart
	name = "star chart"
	desc = "A survey slate preloaded with the coordinates of one region of the system. Insert it into a ship's helm console to chart those contacts onto the navigation readout."
	icon = 'voidcrew/modules/overmap/icons/obj/star_chart.dmi'
	icon_state = "star_chart"
	// We use our own sprite sheet, which carries none of the "o_*" sticker states
	// /obj/item/disk overlays onto icons/obj/devices/floppy_disks.dmi, nor the
	// "datadisk*" reskins. Same opt-out upstream uses for /obj/item/disk/nuclear
	// and /obj/item/disk/bitrunning. Nulling this also blocks the pen-signing and
	// sticker radial paths, which both bail when it isn't the starting sticker.
	sticker_icon_state = null
	/// Zone band this chart reveals (a ZONE_* constant). Unset on this base
	/// type, which is only the shared parent - every sold chart is a subtype.
	var/chart_zone_type = null
	/// Human-readable region label for the upload notification. Unset here for
	/// the same reason as chart_zone_type.
	var/zone_label = null

/// The floppy-disk reskins are all icon states in floppy_disks.dmi; applying one
/// would blank the chart, so charts aren't reskinnable.
/obj/item/disk/star_chart/setup_reskins()
	return

/obj/item/disk/star_chart/attack_self(mob/user)
	balloon_alert(user, "insert into helm console!")

/**
 * Called by the helm console when this chart is inserted into it (see
 * attackby() in _helm.dm). Returns TRUE if the chart was consumed.
 */
/obj/item/disk/star_chart/proc/upload_to_ship(obj/structure/overmap/ship/ship, mob/user)
	if(isnull(chart_zone_type))
		balloon_alert(user, "slate is blank!")
		return FALSE
	var/charted = ship.chart_zone(chart_zone_type)
	if(charted > 0)
		ship.ship_notify("Star chart uploaded: [charted] new contact[charted > 1 ? "s" : ""] in [zone_label] added to the navigation readout.", "SENSORS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 25)
		to_chat(user, span_notice("You insert [src] into the console and upload it to the ship's navigation readout: [charted] new contact[charted > 1 ? "s" : ""] charted."))
	else
		to_chat(user, span_notice("You insert [src] into the console, but the navigation readout already covers [zone_label]."))
	qdel(src)
	return TRUE

/obj/item/disk/star_chart/green
	name = "star chart (neutral ring)"
	desc = "A survey slate mapping the neutral ring. Use it aboard a ship to chart every planet, signal, station and storm in green-zone space."
	icon_state = "star_chart_green"
	chart_zone_type = ZONE_GREEN
	zone_label = "the neutral ring"

/obj/item/disk/star_chart/yellow
	name = "star chart (contested lanes)"
	desc = "A survey slate mapping the contested lanes. Use it aboard a ship to chart every planet, signal, station and storm in yellow-zone space."
	icon_state = "star_chart_yellow"
	chart_zone_type = ZONE_YELLOW
	zone_label = "the contested lanes"

/obj/item/disk/star_chart/red
	name = "star chart (lawless deep)"
	desc = "A survey slate mapping the lawless deep. Use it aboard a ship to chart every planet, signal, station and storm in red-zone space."
	icon_state = "star_chart_red"
	chart_zone_type = ZONE_RED
	zone_label = "the lawless deep"
