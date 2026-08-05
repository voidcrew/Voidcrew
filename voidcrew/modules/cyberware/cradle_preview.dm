/**
 * # Chrome Cradle body preview
 *
 * The rig's mirror: a nude mannequin of whoever is on the slab, wearing every
 * piece of chrome that reads from outside the body, drawn live into the console
 * beside the racks. It rotates on demand, rebuilds whenever the occupant's
 * hardware changes, and ghosts in the piece they currently have highlighted —
 * so a customer sees the arm before they commit to the arm.
 *
 * Built on tg's preferences/records `map_view` idiom: a screen object whose
 * appearance is copied off a dummy body and drawn by a <ByondUi> map element
 * inside the interface. This object itself is never registered to a client —
 * the cradle hands each viewer a disposable mirror of it with a single-use
 * map key (see ensure_preview_mirror() in chrome_cradle.dm for why).
 *
 * Nothing is ever inserted into the mannequin. A real organ Insert() fires
 * trait grants, ability buttons and processing hooks, which on a preview doll
 * is either wasted or actively wrong — a Ghostskin weave would turn its own
 * mannequin invisible. The preview instead borrows each ware's existing
 * bodypart-overlay datum and hangs it straight on the matching limb: the exact
 * art the worn pipeline draws, and none of the behavior.
 */

/// How solid a ghosted piece (highlighted, not installed) renders on the
/// mannequin. Low enough to read as a proposal at a glance.
#define CYBERWARE_GHOST_ALPHA 120

/**
 * A ghosted worn overlay: the real chrome art at reduced opacity, with the
 * emissive twins dropped — a proposal has no business lighting the room. The
 * cache key differs from the solid overlay's so the two never collide in the
 * limb icon cache.
 */
/datum/bodypart_overlay/augment/cyberware/preview

/datum/bodypart_overlay/augment/cyberware/preview/generate_icon_cache()
	. = ..()
	. += "cradle_ghost"

/datum/bodypart_overlay/augment/cyberware/preview/get_overlay(layer, obj/item/bodypart/limb)
	. = list()
	for(var/image/ghost as anything in implant.get_overlay(bitflag_to_layer(layer), limb))
		if(ghost.plane == EMISSIVE_PLANE)
			continue
		ghost.alpha = CYBERWARE_GHOST_ALPHA
		. += ghost

/**
 * The per-viewer, per-open carrier that actually reaches a client.
 *
 * Three properties, each covering a verified way the panel goes black:
 * - It survives `show_hud()` — buckling lies the patient down and installs
 *   sedate them, and every one of those body-position changes runs
 *   `client.clear_screen()`, which strips default screen objects off the
 *   client while `screen_maps` still claims they're registered.
 * - It carries NO background rectangle, deliberately. The character previews
 *   that frame correctly (records, prefs) have exactly one screen object on
 *   their map; the rect idiom belongs to camera-class popups, whose turf
 *   content isn't made of screen objects and so defines no extent at all.
 *   An extra rect is the one structural difference a mis-framed cradle map
 *   had from the working previews.
 * - Its display path re-validates the cached plane group: a popup plane
 *   group cached against a hud the client no longer uses draws nothing.
 */
/// How many times larger than life the mannequin draws. BYOND sizes a
/// secondary map off the client VIEW (19x15), never off its content — the
/// reference is explicit: "the map has a native size" of the view — and the
/// console's control runs zoom=1 (see ChromeCradle.tsx), showing a native-
/// pixel 263x478 window onto that view, anchored at the view's TOP-LEFT
/// (live-verified). A natural-size figure is a 32px speck, so it is scaled up
/// instead; PIXEL_SCALE (already in every mob's appearance flags) keeps the
/// upscale crisp, and 8x = 256px is the largest whole multiple that fits the
/// 263px window width.
#define CRADLE_MIRROR_SCALE 8

/atom/movable/screen/map_view/chrome_mirror
	name = "chrome_mirror"
	clear_with_screen = FALSE

/atom/movable/screen/map_view/chrome_mirror/generate_view(map_key)
	. = ..()
	// The control's zoom=1 window is CENTRED on the 608x480 view (live-
	// verified: a figure parked in the left quarter vanished entirely; the
	// top-left anchor seen earlier belongs only to letterbox-less auto-zoom).
	// Tile 10, row 8 is the exact view centre — px 304,240 — which is the
	// centre of the visible window, and still overlaps the window under any
	// corner-anchored crop besides.
	set_position(10, 8)

/**
 * Takes the master preview's current look while keeping this mirror's own
 * placement and display scale. Assigning `appearance` overwrites `transform`
 * (the dummy's height offset rides in it), so the display scale has to be
 * re-applied after every sync — scaling the whole matrix keeps any height
 * offset proportional to the blown-up body.
 */
/atom/movable/screen/map_view/chrome_mirror/proc/adopt_look(datum/source_appearance)
	appearance = source_appearance
	// The mob appearance arrives with TILE_BOUND|KEEP_TOGETHER, and both put a
	// box around the render that a transform-scaled figure spills out of —
	// live test: the blown-up mannequin drew amputated mid-body at the box
	// edge. The mannequin carries no filters, so KEEP_TOGETHER buys nothing
	// here; drop both and let the figure draw at its full scaled extent.
	appearance_flags &= ~(TILE_BOUND | KEEP_TOGETHER)
	var/matrix/scaled = transform ? matrix(transform) : matrix()
	scaled.Scale(CRADLE_MIRROR_SCALE)
	transform = scaled

/atom/movable/screen/map_view/chrome_mirror/display_to_client(client/show_to)
	// A plane group cached against a hud the client no longer uses would be
	// returned by the early-out in the base proc and draw nothing — detect
	// the stale hud and rebuild instead.
	var/datum/weakref/hud_ref = viewers_to_huds[WEAKREF(show_to)]
	var/datum/hud/cached_hud = hud_ref?.resolve()
	if(cached_hud && cached_hud != show_to.mob?.hud_used)
		hide_from_client(show_to)
	var/datum/plane_master_group/popup/group = ..()
	// A body preview is a product shot, not a place. The popup has no turfs,
	// no light sources, and its lighting backdrop never reaches the popup map
	// (overlay_fullscreen doesn't map-assign; round-868 trace: backdrop
	// map=NONE, lighting plate alpha=255) — so the moment the mannequin's
	// appearance puts real content on the lighting/emissive planes (worn
	// chrome carries emissive twins; plain records/prefs dummies never do)
	// the multiply-composited lighting stack blacks out the whole game plate.
	// Render the preview fullbright instead: drop that stack from this
	// popup's group. force_hidden survives every show_hud() re-show.
	suppress_lighting(show_to.mob, group)
	// The base proc's cached-group early return hands the group back WITHOUT
	// re-adding its plane masters to client.screen — so a re-display could
	// never recover masters something stripped. Re-assert them every time;
	// hide-then-show is idempotent, and show_to() skips force_hidden plates.
	group?.refresh_hud()
	return group

/// Hides the lighting/emissive composite plates in this popup's plane group so
/// the mannequin renders fullbright no matter what its appearance carries.
/atom/movable/screen/map_view/chrome_mirror/proc/suppress_lighting(mob/viewer, datum/plane_master_group/group)
	if(isnull(viewer) || isnull(group))
		return
	var/static/list/suppressed_planes = list(
		RENDER_PLANE_TURF_LIGHTING,
		RENDER_PLANE_EMISSIVE,
		RENDER_PLANE_EMISSIVE_BLOOM_MASK,
		RENDER_PLANE_EMISSIVE_BLOOM,
		RENDER_PLANE_SPECULAR_MASK,
		RENDER_PLANE_SPECULAR,
		RENDER_PLANE_LIGHTING,
		RENDER_PLANE_LIGHT_MASK,
	)
	for(var/key in group.plane_masters)
		var/atom/movable/screen/plane_master/plane = group.plane_masters[key]
		if(plane.real_plane in suppressed_planes)
			plane.hide_plane(viewer)

/atom/movable/screen/map_view/chrome_preview
	name = "chrome_preview"
	/// The mannequin we copy our appearance off. Private to this cradle.
	var/mob/living/carbon/human/dummy/body
	/// Overlay datums currently hung on the mannequin's limbs, mapped to the
	/// limb they went on, so the next rebuild can take them all back off.
	var/list/hung_overlays = list()
	/// The ghost overlays we minted ourselves — these we own and delete.
	var/list/ghost_overlays = list()
	/// Facing, held across rebuilds. Assigning `appearance` carries the
	/// mannequin's own dir with it, which would undo every rotation on every
	/// install; we re-apply this afterwards instead.
	var/preview_dir = SOUTH

/atom/movable/screen/map_view/chrome_preview/Destroy()
	clear_hung_overlays()
	QDEL_NULL(body)
	return ..()

/// Spin the mannequin a quarter turn. `clockwise` is the player's reading of
/// it, so it maps to BYOND's negative turn.
/atom/movable/screen/map_view/chrome_preview/proc/rotate(clockwise = TRUE)
	preview_dir = turn(preview_dir, clockwise ? -90 : 90)
	setDir(preview_dir)

/**
 * Rebuilds the mannequin from scratch: nude body off the patient's DNA, then
 * every installed ware's worn overlay, then the highlighted piece ghosted on
 * top. Safe to call as often as the UI wants — it is the only thing that ever
 * writes the preview.
 *
 * With no patient the mannequin is left exactly as it was: the interface hides
 * the portrait entirely when the slab is empty, which unmounts the map control
 * client-side, so there is nothing to blank.
 */
/atom/movable/screen/map_view/chrome_preview/proc/refresh(mob/living/carbon/patient, obj/item/organ/ghost_ware)
	clear_hung_overlays()
	if(!istype(patient) || QDELETED(patient))
		return
	// A brand new mannequin every rebuild rather than a wiped and reused one.
	// Reuse means putting a body back together through tg's incremental icon
	// machinery, and that machinery is built to skip work: wipe_state() cuts
	// every overlay off, then update_body_parts() compares each limb's render
	// key, finds it unchanged, and draws nothing at all. A dummy is born fully
	// drawn, so starting from one sidesteps the whole problem. The console only
	// rebuilds on a real event — lying down, highlighting a piece, an install —
	// never on a timer, so this is the same cost the preferences menu pays every
	// time you open it.
	QDEL_NULL(body)
	body = new
	// Nude copy: species, features and colours off the patient, no equipment.
	// Underwear rides along, which is how the character-setup preview reads
	// "naked" in this game — and worn chrome draws over it regardless.
	patient.dna.copy_dna(body.dna, COPY_DNA_SE | COPY_DNA_SPECIES)
	if(ishuman(patient))
		var/mob/living/carbon/human/human_patient = patient
		human_patient.copy_clothing_prefs(body)
	// Drop the limb render-key cache AFTER the DNA is on: copy_dna() runs
	// set_species(), which swaps the limbs out and repopulates the cache on its
	// way through. Clearing before that point gets the cache refilled behind our
	// back, and the redraw below then decides nothing changed.
	body.icon_render_keys = list()
	body.updateappearance(icon_update = TRUE, mutcolor_update = TRUE, mutations_overlay_update = TRUE)

	var/list/obj/item/organ/installed = get_installed_cyberware(patient)
	for(var/obj/item/organ/ware as anything in installed)
		hang_worn_overlay(ware, ghost = FALSE)
	// A piece already in the body is being inspected, not proposed — only
	// hardware the patient hasn't got yet earns a ghost.
	if(ghost_ware && !QDELETED(ghost_ware) && !(ghost_ware in installed))
		hang_worn_overlay(ghost_ware, ghost = TRUE)
	tint_optics(installed, ghost_ware)

	body.update_body_parts()
	appearance = body.appearance
	setDir(preview_dir)

/// Hangs one ware's worn art on the mannequin's matching limb. Silently does
/// nothing for chrome with no outside read — most of the roster is internal.
/atom/movable/screen/map_view/chrome_preview/proc/hang_worn_overlay(obj/item/organ/ware, ghost = FALSE)
	var/obj/item/organ/cyberimp/implant = ware
	if(!istype(implant) || isnull(implant.bodypart_aug))
		return
	var/obj/item/bodypart/limb = body.get_bodypart(implant.zone)
	if(isnull(limb))
		return
	var/datum/bodypart_overlay/augment/overlay = implant.bodypart_aug
	if(ghost)
		overlay = new /datum/bodypart_overlay/augment/cyberware/preview(implant)
		ghost_overlays += overlay
	// One batched update_body_parts() at the end of the rebuild instead of one
	// per overlay.
	limb.add_bodypart_overlay(overlay, update = FALSE)
	hung_overlays[overlay] = limb

/**
 * Chrome optics hang no bodypart overlay — they recolour the eyes through the
 * organ colour priority. Mirror that on the mannequin so a Nightshade actually
 * reads on the face, and clear the previous pass first so swapping optics
 * doesn't leave the old colour behind.
 */
/atom/movable/screen/map_view/chrome_preview/proc/tint_optics(list/obj/item/organ/installed, obj/item/organ/ghost_ware)
	body.remove_eye_color(EYE_COLOR_ORGAN_PRIORITY, update_body = FALSE)
	var/obj/item/organ/eyes/optics
	for(var/obj/item/organ/ware as anything in installed)
		if(istype(ware, /obj/item/organ/eyes))
			optics = ware
			break
	// A highlighted set of optics wins the preview — that is the whole point of
	// highlighting them.
	if(istype(ghost_ware, /obj/item/organ/eyes) && !(ghost_ware in installed))
		optics = ghost_ware
	if(isnull(optics))
		return
	if(optics.eye_color_left)
		body.add_eye_color_left(optics.eye_color_left, EYE_COLOR_ORGAN_PRIORITY, update_body = FALSE)
	if(optics.eye_color_right)
		body.add_eye_color_right(optics.eye_color_right, EYE_COLOR_ORGAN_PRIORITY, update_body = FALSE)

/// Takes every overlay this preview put on the mannequin back off, and deletes
/// the ghosts it owns. The limbs are checked because a species swap between
/// rebuilds replaces them wholesale.
/atom/movable/screen/map_view/chrome_preview/proc/clear_hung_overlays()
	for(var/datum/bodypart_overlay/overlay as anything in hung_overlays)
		var/obj/item/bodypart/limb = hung_overlays[overlay]
		if(!QDELETED(limb))
			limb.remove_bodypart_overlay(overlay, update = FALSE)
	hung_overlays.Cut()
	for(var/datum/bodypart_overlay/ghost as anything in ghost_overlays)
		qdel(ghost)
	ghost_overlays.Cut()

// ---- Slot grouping -----------------------------------------------------

/**
 * How the cradle files chrome on screen: one row per body system, in head-down
 * order, each owning the organ slots that live there. This is presentation
 * only — the slots themselves are the real uniqueness rule.
 *
 * Anything chrome whose slot isn't listed here falls into a trailing "Other
 * Hardware" group rather than vanishing, so a new slot always shows up
 * somewhere even before it gets a home.
 */
GLOBAL_LIST_INIT(cyberware_ui_groups, list(
	list("id" = "cortex", "name" = "Frontal Cortex", "region" = "head", "slots" = list(ORGAN_SLOT_CYBERWARE_GOVERNOR, ORGAN_SLOT_CYBERWARE_RIGGER)),
	list("id" = "ocular", "name" = "Ocular System", "region" = "head", "slots" = list(ORGAN_SLOT_EYES)),
	list("id" = "aural", "name" = "Auditory System", "region" = "head", "slots" = list(ORGAN_SLOT_CYBERWARE_EARS, ORGAN_SLOT_CYBERWARE_LARYNX)),
	list("id" = "os", "name" = "Operating System", "region" = "torso", "slots" = list(ORGAN_SLOT_CYBERWARE_OS)),
	list("id" = "nervous", "name" = "Nervous System", "region" = "torso", "slots" = list(ORGAN_SLOT_CYBERWARE_NERVOUS)),
	list("id" = "circulatory", "name" = "Circulatory System", "region" = "torso", "slots" = list(ORGAN_SLOT_CYBERWARE_FILTER, ORGAN_SLOT_HEART_AID, ORGAN_SLOT_CYBERWARE_HEART_AUX)),
	list("id" = "seal", "name" = "Environment Seal", "region" = "torso", "slots" = list(ORGAN_SLOT_CYBERWARE_SEAL)),
	list("id" = "integumentary", "name" = "Integumentary System", "region" = "torso", "slots" = list(ORGAN_SLOT_CYBERWARE_DERMAL, ORGAN_SLOT_CYBERWARE_SKIN, ORGAN_SLOT_CYBERWARE_INK)),
	list("id" = "skeleton", "name" = "Skeletal Frame", "region" = "torso", "slots" = list(ORGAN_SLOT_CYBERWARE_FRAME)),
	list("id" = "digestive", "name" = "Digestive Tract", "region" = "torso", "slots" = list(ORGAN_SLOT_CYBERWARE_GUT, ORGAN_SLOT_CYBERWARE_STASH)),
	list("id" = "arms", "name" = "Arm Hardware", "region" = "arms", "slots" = list(ORGAN_SLOT_RIGHT_ARM_AUG, ORGAN_SLOT_LEFT_ARM_AUG)),
	list("id" = "hands", "name" = "Hands", "region" = "arms", "slots" = list(ORGAN_SLOT_CYBERWARE_HANDS)),
	list("id" = "legs", "name" = "Mobility", "region" = "legs", "slots" = list(ORGAN_SLOT_CYBERWARE_LEGS)),
))

/// slot string -> the group id that owns it. Built once off the table above.
GLOBAL_LIST_EMPTY(cyberware_slot_to_group)

/// Which UI group a piece of chrome files under. Never null: unrecognised
/// slots land in the catch-all.
/proc/get_cyberware_group_id(obj/item/organ/ware)
	if(!length(GLOB.cyberware_slot_to_group))
		for(var/list/group as anything in GLOB.cyberware_ui_groups)
			for(var/slot in group["slots"])
				GLOB.cyberware_slot_to_group[slot] = group["id"]
	return GLOB.cyberware_slot_to_group[ware.slot] || "other"

// ---- Parlor price index ------------------------------------------------

/**
 * organ typepath -> what Splice charges for it, so the cradle can quote a
 * price next to the neural cost. Built lazily on first use because cased pairs
 * only reveal their contents once one has actually been opened.
 *
 * `paired` marks a piece sold two-to-a-case: the price on the card is the
 * whole case's, not this half's.
 */
GLOBAL_LIST_EMPTY(cyberware_price_index)
GLOBAL_VAR_INIT(cyberware_prices_indexed, FALSE)

/proc/get_cyberware_price(obj/item/organ/ware)
	if(!GLOB.cyberware_prices_indexed)
		build_cyberware_price_index()
	return GLOB.cyberware_price_index[ware.type]

/proc/build_cyberware_price_index()
	GLOB.cyberware_prices_indexed = TRUE
	for(var/datum/shop_sku/ripperdoc/sku_type as anything in subtypesof(/datum/shop_sku/ripperdoc))
		var/item_path = initial(sku_type.item_path)
		if(!ispath(item_path, /obj/item))
			continue
		var/list/price = list(
			"credits" = initial(sku_type.price_credits),
			"vouchers" = initial(sku_type.price_vouchers),
			"paired" = FALSE,
		)
		if(ispath(item_path, /obj/item/organ))
			GLOB.cyberware_price_index[item_path] = price
			continue
		// Cased pairs and knuckle sets: crack one open in nullspace to learn
		// which organs it holds, so each half can quote the case's price. The
		// sample and its contents go straight back out — nothing here is ever
		// meant to reach a turf.
		var/obj/item/sample = new item_path(null)
		for(var/obj/item/organ/held in sample.contents)
			var/list/pair_price = price.Copy()
			pair_price["paired"] = TRUE
			GLOB.cyberware_price_index[held.type] = pair_price
		for(var/atom/movable/packed as anything in sample.contents.Copy())
			qdel(packed)
		qdel(sample)

// ---- Console art -------------------------------------------------------

/**
 * The console faceplate, composited by tools/chrome_plate/make_plate.py. Its
 * bezels are drawn at the exact GEOMETRY coordinates the interface positions
 * its panels from, so re-run that script if the layout moves or the wells will
 * no longer line up with the readouts.
 */
/datum/asset/simple/chrome_cradle_plate
	assets = list(
		"chrome_cradle_plate.png" = 'voidcrew/modules/cyberware/icons/chrome_cradle_plate.png',
	)

// ---- Card art ----------------------------------------------------------

/**
 * Inventory sprites for the rack cards, as one CSS spritesheet rather than a
 * base64 blob per row: the cradle re-pushes its whole ware list on every servo
 * beat of an install, and inlined icons would put the entire roster on the wire
 * several times a second.
 *
 * Keyed by icon state, since that IS what makes two pieces look different.
 * The interface builds `chrome32x32 <key>` off the `icon` field of a ware.
 */
/datum/asset/spritesheet_batched/chrome
	name = "chrome"

/datum/asset/spritesheet_batched/chrome/create_spritesheets()
	var/list/seen = list()
	var/list/ware_types = typesof(/obj/item/organ/cyberimp/cyberware) \
		+ typesof(/obj/item/organ/eyes/robotic/cyberware) \
		+ typesof(/obj/item/organ/cyberimp/arm/toolkit/cyberware)
	for(var/obj/item/organ/ware as anything in ware_types)
		var/state = initial(ware.icon_state)
		if(!state || seen[state])
			continue
		var/icon_file = initial(ware.icon)
		if(!icon_exists(icon_file, state))
			continue
		seen[state] = TRUE
		insert_icon(get_cyberware_card_icon_key(state), uni_icon(icon_file, state, SOUTH))

/// The spritesheet key for a ware's card art. Prefixed so chrome states can
/// never collide with another sheet's class names.
/proc/get_cyberware_card_icon_key(icon_state)
	return "chrome-[icon_state]"

#undef CYBERWARE_GHOST_ALPHA
