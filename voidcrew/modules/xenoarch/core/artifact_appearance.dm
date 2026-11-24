/**
 * # Artifact looks, sounds and examine text
 *
 * Shapes come from icons/artifacts.dmi, assembled from clean sources only (CC BY-SA 3.0):
 * NovaSector 5ce2bd2215c0 artifacts.dmi states 7-13 (pylon, terminal, vents, growth, three
 * crystals), Polaris 6cd19fe0dec6 xenoarchaeology.dmi ano10/70/80/120/130/140/150 (torus,
 * monolith, spire, idol, cradle, effigy, spindle), and Aurora's crystal_madness (shard; its
 * active frames were drawn for Voidcrew). No Goon art: Nova artifact_1-6 and Bay/Polaris
 * ano00/20/30/40/50 are Goon copies and are not used.
 *
 * While it sleeps an artifact breathes a faint glow in its energy kind's colour. Awake, it plays
 * its shape's active animation, glows brighter, sheds particles, lights the room a little and
 * hums. Waking, falling asleep and each burst it releases have their own small moment.
 */

/// Shape key -> list("name", "descs", "tag" = list(pixel_x, pixel_y) for the label sticker)
GLOBAL_LIST_INIT(artifact_shapes, list(
	"pylon" = list(
		"name" = "alien pylon",
		"descs" = list(
			"A grey orb held above a slim stand by nothing you can see.",
			"A metal stand topped with a perfectly smooth grey sphere.",
		),
		"tag" = list(15, -22),
	),
	"terminal" = list(
		"name" = "alien terminal",
		"descs" = list(
			"A dark glass screen in a heavy frame, lettered in a script nobody reads.",
			"It looks like a console. The keys are the wrong shape for any hand you know of.",
		),
		"tag" = list(22, -22),
	),
	"vents" = list(
		"name" = "vented casing",
		"descs" = list(
			"A heavy grey casing, louvred down one side.",
			"A squat metal housing with vents along its flank. Nothing comes out of them.",
		),
		"tag" = list(23, -22),
	),
	"growth" = list(
		"name" = "fronded mass",
		"descs" = list(
			"A tangle of hard green fronds around a single lidded eye.",
			"Green fronds, like metal grown as a plant, curl around a closed eye.",
		),
		"tag" = list(21, -21),
	),
	"crystal_green" = list(
		"name" = "large crystal",
		"descs" = list(
			"A green crystal the size of a dog. It shines faintly as it catches the light.",
			"A green crystal with a faint glow somewhere deep inside.",
		),
		"tag" = list(17, -21),
	),
	"crystal_violet" = list(
		"name" = "large crystal",
		"descs" = list(
			"A violet crystal the size of a dog. Something twinkles deep inside it.",
			"A violet crystal, cold and heavy, with a faint inner glow.",
		),
		"tag" = list(17, -21),
	),
	"crystal_blue" = list(
		"name" = "large crystal",
		"descs" = list(
			"A blue crystal the size of a dog. It shines faintly as it catches the light.",
			"A blue crystal, clear near the edges and cloudy at the heart.",
		),
		"tag" = list(17, -21),
	),
	"torus" = list(
		"name" = "black torus",
		"descs" = list(
			"A ring of black stone, cold and smooth. The hole looks deeper than the ring is thick.",
			"A small black ring, far heavier than it has any right to be.",
		),
		"tag" = list(15, -14),
	),
	"monolith" = list(
		"name" = "green monolith",
		"descs" = list(
			"A leaning slab of green stone, striped with darker veins.",
			"A green slab with grooves down its face, too regular to be weathering.",
		),
		"tag" = list(20, -23),
	),
	"spire" = list(
		"name" = "violet spire",
		"descs" = list(
			"A twisted violet spire, ridged like horn.",
			"A curled violet spike. The ridges on it are warm to the touch.",
		),
		"tag" = list(22, -23),
	),
	"idol" = list(
		"name" = "sandstone idol",
		"descs" = list(
			"A weathered figure with its arms raised. Its face has been worn away.",
			"A sandstone figure holding up two empty hands.",
		),
		"tag" = list(17, -17),
	),
	"cradle" = list(
		"name" = "black cradle",
		"descs" = list(
			"A forked pedestal of black metal, shaped to hold something that isn't there.",
			"Two black prongs rising from a heavy base. Whatever they held is gone.",
		),
		"tag" = list(14, -22),
	),
	"effigy" = list(
		"name" = "pale effigy",
		"descs" = list(
			"A smooth white figure the height of a child. It has no mouth.",
			"A pale figure standing very straight. Its eyes are two dark beads.",
		),
		"tag" = list(16, -23),
	),
	"spindle" = list(
		"name" = "red spindle",
		"descs" = list(
			"A red crystal turning slowly in place, touching nothing.",
			"A spindle of red crystal that hangs a hand's width off the ground and turns.",
		),
		"tag" = list(14, -19),
	),
	"shard" = list(
		"name" = "pale shard",
		"descs" = list(
			"A cluster of pale blue crystal growing out of a dark stone.",
			"Pale blue crystals jut from a lump of black rock like broken glass.",
		),
		"tag" = list(16, -23),
	),
))

/// Close-up details; each artifact keeps two.
GLOBAL_LIST_INIT(artifact_examine_notes, list(
	"It is heavier than it looks.",
	"There are no seams, bolts or tool marks anywhere on it.",
	"It is a few degrees warmer than the air around it.",
	"Grit from the dig is still packed into its crevices.",
	"Up close, the surface has a fine grain, like fingerprints.",
	"It doesn't ring when tapped. It doesn't make any sound at all.",
	"Dust doesn't seem to settle on it.",
	"It smells faintly of ozone.",
))

/// Lines for falling asleep: "[artifact] [line]"
#define ARTIFACT_SLEEP_LINES list("grows dull.", "fades.", "goes very still.", "falls quiet.")

/// Glow levels, faintest first.
#define ARTIFACT_GLOW_NONE 0
#define ARTIFACT_GLOW_IDLE 1
#define ARTIFACT_GLOW_RESTING 2
#define ARTIFACT_GLOW_AWAKE 3

/obj/machinery/artifact
	/// GLOB.artifact_shapes key. Set on a subtype or map to fix the shape; random otherwise.
	var/shape
	/// Two close-up details for examine_more
	var/list/examine_notes
	/// Glow level and colour now showing, so the filter is only rebuilt when they change
	var/glow_level = ARTIFACT_GLOW_NONE
	var/glow_color
	/// Shared particle type now attached
	var/particles_shown
	/// Hum while awake
	var/datum/looping_sound/hum
	/// Shown on the last visual refresh: awake at all
	var/shown_awake = FALSE

/// Picks a shape if none is set and takes its name, description and icon.
/obj/machinery/artifact/proc/setup_shape()
	if(!GLOB.artifact_shapes[shape])
		shape = pick(GLOB.artifact_shapes)
	var/list/shape_data = GLOB.artifact_shapes[shape]
	name = shape_data["name"]
	desc = pick(shape_data["descs"])
	var/list/notes = GLOB.artifact_examine_notes.Copy()
	examine_notes = list()
	for(var/i in 1 to 2)
		examine_notes += pick_n_take(notes)
	update_appearance()

/obj/machinery/artifact/update_icon_state()
	icon_state = "[shape][shown_awake ? "_active" : ""]"
	return ..()

/obj/machinery/artifact/update_overlays()
	. = ..()
	if(!label)
		return
	var/list/tag_offset = GLOB.artifact_shapes[shape]?["tag"] || list(16, -22)
	var/mutable_appearance/sticker = mutable_appearance(icon, "label_tag")
	sticker.pixel_x = tag_offset[1]
	sticker.pixel_y = tag_offset[2]
	. += sticker

/obj/machinery/artifact/examine(mob/user)
	. = ..()
	if(is_dug())
		. += "A field tag wired to it reads <b>[serial]</b>."
	if(label)
		. += label.examine_text()
	if(damaged)
		. += span_warning("Cracks run through it where it came out of the rock badly.")
	if(anchored)
		. += "It is bolted to the deck."
	if(!shown_awake)
		return
	var/datum/artifact_energy_kind/kind = visual_kind()
	if(kind)
		. += span_notice(pick(kind.awake_examine))
	if(all_awake_resting())
		. += "Its glow gutters, as if gathering itself."

/obj/machinery/artifact/examine_more(mob/user)
	. = ..()
	. += examine_notes

/// The kind that sets its look: the main effect's, or the second's if it has no main.
/obj/machinery/artifact/proc/visual_kind()
	var/datum/artifact_effect/lead = main_effect || second_effect
	return lead ? artifact_energy_kind(lead.energy_kind) : null

/// Every awake effect is an aura resting between runs.
/obj/machinery/artifact/proc/all_awake_resting()
	var/any_awake = FALSE
	for(var/datum/artifact_effect/effect as anything in effects())
		if(!effect.activated)
			continue
		any_awake = TRUE
		if(!effect.exhausted)
			return FALSE
	return any_awake

// ===== Moments =====

/// An effect woke. The first one to wake brings the whole artifact to life.
/obj/machinery/artifact/proc/effect_woke(datum/artifact_effect/effect)
	SEND_SIGNAL(src, COMSIG_ARTIFACT_EFFECT_ACTIVATED, effect)
	if(!shown_awake && !QDELETED(src))
		var/datum/artifact_energy_kind/kind = visual_kind()
		if(kind)
			visible_message(span_warning(kind.wake_line(src)))
			playsound(src, kind.wake_sound, 50, TRUE)
		throb(1.12)
	update_activity_visuals()

/// An effect went to sleep. When the last one sleeps, so does the artifact.
/obj/machinery/artifact/proc/effect_slept(datum/artifact_effect/effect, quiet = FALSE)
	SEND_SIGNAL(src, COMSIG_ARTIFACT_EFFECT_DEACTIVATED, effect)
	if(QDELETED(src))
		return
	if(shown_awake && !is_active() && !quiet)
		visible_message(span_notice("[src] [pick(ARTIFACT_SLEEP_LINES)]"))
		playsound(src, 'sound/effects/stealthoff.ogg', 40, TRUE)
	update_activity_visuals()

/// An effect let off a burst.
/obj/machinery/artifact/proc/effect_pulsed(datum/artifact_effect/effect)
	var/datum/artifact_energy_kind/kind = artifact_energy_kind(effect.energy_kind)
	playsound(src, kind.pulse_sound, 45, TRUE)
	throb(1.18)
	var/old_level = glow_level
	set_glow(ARTIFACT_GLOW_AWAKE, kind.color, flash = TRUE)
	glow_level = old_level

/// A quick swell and settle.
/obj/machinery/artifact/proc/throb(scale)
	var/matrix/swell = matrix()
	swell.Scale(scale)
	animate(src, transform = swell, time = 0.15 SECONDS, easing = SINE_EASING | EASE_OUT)
	animate(transform = matrix(), time = 0.4 SECONDS, easing = SINE_EASING | EASE_IN)

// ===== Glow, light, particles, hum =====

/**
 * Brings icon, glow, light, particles and hum in line with what the effects are doing.
 * Cheap when nothing changed; `force` rebuilds everything (after effects were replaced).
 */
/obj/machinery/artifact/proc/update_activity_visuals(force = FALSE)
	if(QDELETED(src))
		return
	var/datum/artifact_energy_kind/kind = visual_kind()
	var/awake = is_active() && !suppressed
	var/resting = awake && all_awake_resting()
	if(awake != shown_awake || force)
		shown_awake = awake
		update_appearance(UPDATE_ICON_STATE)

	var/wanted_glow = ARTIFACT_GLOW_NONE
	if(kind && isturf(loc))
		if(!awake)
			wanted_glow = ARTIFACT_GLOW_IDLE
		else
			wanted_glow = resting ? ARTIFACT_GLOW_RESTING : ARTIFACT_GLOW_AWAKE
	set_glow(wanted_glow, kind?.color, force = force)

	var/wanted_particles = (awake && !resting) ? kind?.particle_type : null
	if(wanted_particles != particles_shown || force)
		if(particles_shown)
			remove_shared_particles(particles_shown)
		particles_shown = wanted_particles
		if(particles_shown)
			add_shared_particles(particles_shown)

	update_artifact_light(awake, resting, kind)

	if(awake)
		if(force && hum)
			QDEL_NULL(hum)
		if(!hum && kind?.hum_type)
			hum = new kind.hum_type(src)
		hum?.start()
	else
		hum?.stop()

/// Light: an awake light or darkness effect sets it; otherwise a small glow while awake.
/obj/machinery/artifact/proc/update_artifact_light(awake, resting, datum/artifact_energy_kind/kind)
	if(awake)
		for(var/datum/artifact_effect/effect as anything in effects())
			if(!effect.activated)
				continue
			var/list/override = effect.light_override()
			if(override)
				set_light(override[1], override[2], override[3])
				return
	if(awake && kind)
		set_light(2, resting ? 0.4 : 0.9, kind.color)
	else
		set_light(0)

/// Sets the drop-shadow glow and starts it breathing. `flash` spikes it once, then settles.
/obj/machinery/artifact/proc/set_glow(level, color, force = FALSE, flash = FALSE)
	if(!flash && !force && level == glow_level && color == glow_color)
		return
	glow_level = level
	glow_color = color
	if(level == ARTIFACT_GLOW_NONE || !color)
		remove_filter("artifact_glow")
		return
	var/low_alpha
	var/high_alpha
	var/size
	var/period
	switch(level)
		if(ARTIFACT_GLOW_AWAKE)
			low_alpha = "70"
			high_alpha = "c8"
			size = 2.5
			period = 1 SECONDS
		if(ARTIFACT_GLOW_RESTING)
			low_alpha = "30"
			high_alpha = "60"
			size = 1.5
			period = 2 SECONDS
		else
			low_alpha = "18"
			high_alpha = "50"
			size = 1
			period = 3 SECONDS
	if(flash)
		add_filter("artifact_glow", 2, drop_shadow_filter(0, 0, 4, 0, "[color]ff"))
	else
		add_filter("artifact_glow", 2, drop_shadow_filter(0, 0, size, 0, "[color][low_alpha]"))
	transition_filter_chain("artifact_glow", -1, \
		FilterChainStep(list("color" = "[color][high_alpha]", "size" = size), period, SINE_EASING), \
		FilterChainStep(list("color" = "[color][low_alpha]", "size" = size), period, SINE_EASING))

/// Strips glow, particles, light and hum (deletion).
/obj/machinery/artifact/proc/clear_activity_visuals()
	if(particles_shown)
		remove_shared_particles(particles_shown)
		particles_shown = null
	remove_filter("artifact_glow")
	glow_level = ARTIFACT_GLOW_NONE
	QDEL_NULL(hum)
	set_light(0)

#undef ARTIFACT_SLEEP_LINES
#undef ARTIFACT_GLOW_NONE
#undef ARTIFACT_GLOW_IDLE
#undef ARTIFACT_GLOW_RESTING
#undef ARTIFACT_GLOW_AWAKE
