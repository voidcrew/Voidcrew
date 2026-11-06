/// Backgrounds: owned by P2. See data/backgrounds/spec.md.

// Secure doors: open for the Penitentiary's own staff only

/obj/machinery/door/airlock/outpost/penitentiary
	req_access = list(ACCESS_PENITENTIARY)

/obj/machinery/door/airlock/outpost/penitentiary/glass
	opacity = FALSE
	glass = TRUE

/obj/machinery/door/airlock/outpost/penitentiary/armory
	req_access = list(ACCESS_PENITENTIARY_ARMORY)

/obj/machinery/door/airlock/outpost/penitentiary/capture
	icon = 'icons/obj/doors/airlocks/station/security.dmi'
	overlays_file = 'icons/obj/doors/airlocks/station/overlays.dmi'
	opacity = FALSE
	glass = TRUE
	/// Which capture cell this door closes, set on the map
	var/cell_number = 0

// Escape line: ordinary airlocks

/obj/machinery/door/airlock/security/glass/penitentiary_escape
	req_access = list(ACCESS_PENITENTIARY)
	/// Which escape cell this door closes, set on the map
	var/cell_number = 0

/obj/machinery/door/airlock/security/penitentiary_service
	req_access = list(ACCESS_PENITENTIARY)

/obj/machinery/door/airlock/security/penitentiary_service/glass
	opacity = FALSE
	glass = TRUE
	normal_integrity = 400

/obj/machinery/door/airlock/security/glass/penitentiary_podbay
	req_access = list(ACCESS_PENITENTIARY_PODBAY)

// The intake counter

/obj/machinery/door/window/brigdoor/penitentiary
	req_access = list(ACCESS_PENITENTIARY)

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/door/window/brigdoor/penitentiary, 0)

/obj/machinery/penitentiary_intake_pad
	icon = 'icons/obj/machines/telepad.dmi'
	icon_state = "lpad-idle"

// Fittings

/obj/machinery/computer/outpost_prison_warden/penitentiary

/obj/structure/closet/secure_closet/penitentiary_evidence

/obj/machinery/computer/penitentiary_launch

// Landmarks

/obj/effect/landmark/penitentiary

/obj/effect/landmark/penitentiary/arrival
	name = "penitentiary arrival"

/obj/effect/landmark/penitentiary/escape_cell
	name = "penitentiary escape cell"
	/// Which escape cell this bed is in, set on the map
	var/cell_number = 0

/obj/effect/landmark/penitentiary/capture_cell
	name = "penitentiary capture cell"
	/// Which capture cell this bed is in, set on the map
	var/cell_number = 0

/obj/effect/landmark/penitentiary/massacre_body
	name = "penitentiary massacre body"

/obj/effect/landmark/penitentiary/convict_massacre
	name = "penitentiary massacre convict"

/obj/effect/landmark/penitentiary/pod_cradle
	name = "penitentiary pod cradle"

/obj/effect/landmark/penitentiary/morgue
	name = "penitentiary morgue"
