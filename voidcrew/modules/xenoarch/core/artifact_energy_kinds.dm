/**
 * # Artifact energy kinds
 *
 * The seven kinds of energy an analyser can read off a find (Nova's type_name values). Each
 * kind also sets how an artifact looks and sounds: a faint glow while it sleeps, and a brighter
 * glow, drifting particles, a light and a hum while it is awake. Several effects share each
 * kind, so learning the look narrows a find down without naming what it does.
 *
 * Sounds and particles are existing tg assets.
 */

/// Every energy kind, keyed by ARTIFACT_ENERGY_*.
GLOBAL_LIST_INIT(artifact_energy_kinds, init_artifact_energy_kinds())

/proc/init_artifact_energy_kinds()
	. = list()
	for(var/kind_type in subtypesof(/datum/artifact_energy_kind))
		var/datum/artifact_energy_kind/kind = new kind_type
		.[kind.key] = kind

/// The energy kind datum for a key, falling back to concentrated energy.
/proc/artifact_energy_kind(key)
	return GLOB.artifact_energy_kinds[key] || GLOB.artifact_energy_kinds[ARTIFACT_ENERGY_CONCENTRATED]

/datum/artifact_energy_kind
	/// ARTIFACT_ENERGY_*
	var/key
	/// How the analyser names it
	var/report_name
	/// Glow, light and particle colour
	var/color
	/// Particles drifting off it while awake
	var/particle_type
	/// The hum while awake
	var/hum_type
	/// Played when it wakes
	var/wake_sound
	/// Played on each burst it releases
	var/pulse_sound = 'sound/effects/magic/repulse.ogg'
	/// "[artifact] [line]" when it wakes
	var/list/wake_lines
	/// Examine line while it is awake
	var/list/awake_examine

/datum/artifact_energy_kind/proc/wake_line(atom/artifact)
	return "[artifact] [pick(wake_lines)]"

/datum/artifact_energy_kind/concentrated
	key = ARTIFACT_ENERGY_CONCENTRATED
	report_name = "Concentrated energy"
	color = "#ffb347"
	particle_type = /particles/artifact/concentrated
	hum_type = /datum/looping_sound/artifact_hum/concentrated
	wake_sound = 'sound/effects/magic/charge.ogg'
	wake_lines = list(
		"brightens with a rising whine.",
		"flares, and warm light rolls off it.",
		"starts to hum. You can feel the heat from here.",
	)
	awake_examine = list(
		"It is giving off a low, warm hum.",
		"Heat shimmers off its surface.",
	)

/datum/artifact_energy_kind/psionic
	key = ARTIFACT_ENERGY_PSIONIC
	report_name = "Psionic wavefront"
	color = "#b86bff"
	particle_type = /particles/artifact/psionic
	hum_type = /datum/looping_sound/artifact_hum/psionic
	wake_sound = 'sound/effects/magic/magic_block_mind.ogg'
	pulse_sound = 'sound/effects/hallucinations/far_noise.ogg'
	wake_lines = list(
		"shudders, and the air around it wavers.",
		"goes very quiet, and your ears start to ring.",
		"shimmers like a reflection on water.",
	)
	awake_examine = list(
		"The air around it wavers like heat haze.",
		"Looking at it for long makes your teeth ache.",
	)

/datum/artifact_energy_kind/electromagnetic
	key = ARTIFACT_ENERGY_ELECTROMAGNETIC
	report_name = "Electromagnetic energy"
	color = "#5fd3ff"
	particle_type = /particles/artifact/electromagnetic
	hum_type = /datum/looping_sound/artifact_hum/electromagnetic
	wake_sound = 'sound/effects/supermatter.ogg'
	pulse_sound = 'sound/effects/sparks/sparks2.ogg'
	wake_lines = list(
		"crackles, and static crawls over it.",
		"snaps with a blue spark.",
		"buzzes, and the hair on your arms stands up.",
	)
	awake_examine = list(
		"Static crawls across its surface.",
		"It buzzes faintly, like a transformer.",
	)

/datum/artifact_energy_kind/particle
	key = ARTIFACT_ENERGY_PARTICLE
	report_name = "High-frequency particles"
	color = "#e6efff"
	particle_type = /particles/artifact/particle
	hum_type = /datum/looping_sound/artifact_hum/particle
	wake_sound = 'sound/effects/magic/cosmic_energy.ogg'
	wake_lines = list(
		"brightens, and motes of light lift off it.",
		"glitters as if dusted with frost.",
		"gives off a thin, high tone.",
	)
	awake_examine = list(
		"Tiny motes of light drift off its surface.",
		"It glitters, though nothing is shining on it.",
	)

/datum/artifact_energy_kind/organic
	key = ARTIFACT_ENERGY_ORGANIC
	report_name = "Organically reactive particles"
	color = "#ff5f7a"
	particle_type = /particles/artifact/organic
	hum_type = /datum/looping_sound/artifact_hum/organic
	wake_sound = 'sound/effects/magic/enter_blood.ogg'
	pulse_sound = 'sound/effects/singlebeat.ogg'
	wake_lines = list(
		"swells slightly, then settles into a slow pulse.",
		"flushes a dull red.",
		"twitches.",
	)
	awake_examine = list(
		"It pulses slowly, like something breathing.",
		"Its surface is damp and faintly warm.",
	)

/datum/artifact_energy_kind/bluespace
	key = ARTIFACT_ENERGY_BLUESPACE
	report_name = "Bluespace phasing"
	color = "#4a6bff"
	particle_type = /particles/artifact/bluespace
	hum_type = /datum/looping_sound/artifact_hum/bluespace
	wake_sound = 'sound/effects/phasein.ogg'
	pulse_sound = 'sound/effects/magic/blink.ogg'
	wake_lines = list(
		"blurs at the edges.",
		"flickers, as if it were briefly somewhere else.",
		"seems to lean without moving.",
	)
	awake_examine = list(
		"Its edges won't hold still.",
		"It is hard to say exactly how far away it is.",
	)

/datum/artifact_energy_kind/synthesis
	key = ARTIFACT_ENERGY_SYNTHESIS
	report_name = "Atomic synthesis"
	color = "#7dff6a"
	particle_type = /particles/artifact/synthesis
	hum_type = /datum/looping_sound/artifact_hum/synthesis
	wake_sound = 'sound/effects/bubbles/bubbles.ogg'
	pulse_sound = 'sound/effects/spray.ogg'
	wake_lines = list(
		"fizzes, and a sharp chemical smell rises from it.",
		"beads with moisture.",
		"hisses softly.",
	)
	awake_examine = list(
		"It fizzes faintly. The air near it tastes of metal.",
		"A sharp, clean smell hangs around it.",
	)

// ===== Hums =====

/datum/looping_sound/artifact_hum
	volume = 20
	extra_range = -8
	falloff_distance = 2
	falloff_exponent = 5
	ignore_walls = FALSE
	vary = TRUE

/datum/looping_sound/artifact_hum/concentrated
	mid_sounds = list('sound/machines/sm/loops/calm.ogg' = 1)
	mid_length = 10 SECONDS
	volume = 15

/datum/looping_sound/artifact_hum/psionic
	mid_sounds = list('sound/ambience/misc/ambimystery.ogg' = 1)
	mid_length = 10 SECONDS
	volume = 12

/datum/looping_sound/artifact_hum/electromagnetic
	mid_sounds = list(
		'sound/machines/tcomms/tcomms_mid1.ogg' = 1,
		'sound/machines/tcomms/tcomms_mid2.ogg' = 1,
		'sound/machines/tcomms/tcomms_mid3.ogg' = 1,
		'sound/machines/tcomms/tcomms_mid4.ogg' = 1,
	)
	mid_length = 2 SECONDS

/datum/looping_sound/artifact_hum/particle
	mid_sounds = list('sound/machines/hypertorus/loops/hypertorus_nominal.ogg' = 1)
	mid_length = 6.6 SECONDS
	volume = 12

/datum/looping_sound/artifact_hum/organic
	mid_sounds = list('sound/effects/singlebeat.ogg' = 1)
	mid_length = 1.6 SECONDS
	volume = 15

/datum/looping_sound/artifact_hum/bluespace
	mid_sounds = list(
		'sound/machines/gravgen/grav_gen_mid1.ogg' = 12,
		'sound/machines/gravgen/grav_gen_mid2.ogg' = 1,
	)
	mid_length = 2.3 SECONDS
	volume = 15

/datum/looping_sound/artifact_hum/synthesis
	mid_sounds = list(
		'sound/effects/soup_boil/soup_boil1.ogg' = 1,
		'sound/effects/soup_boil/soup_boil2.ogg' = 1,
		'sound/effects/soup_boil/soup_boil3.ogg' = 1,
		'sound/effects/soup_boil/soup_boil4.ogg' = 1,
	)
	mid_length = 3 SECONDS
	volume = 15

// ===== Particles =====
// Shared holders (add_shared_particles): one emitter per kind serves every artifact of that kind.

/particles/artifact
	icon = 'icons/effects/particles/generic.dmi'
	icon_state = "dot"
	width = 64
	height = 64
	count = 24
	spawning = 0.6
	lifespan = 1.5 SECONDS
	fade = 1 SECONDS
	fadein = 0.2 SECONDS
	position = generator(GEN_CIRCLE, 6, 13, NORMAL_RAND)
	scale = generator(GEN_VECTOR, list(0.4, 0.4), list(0.8, 0.8), NORMAL_RAND)

/particles/artifact/concentrated
	color = "#ffb347"
	velocity = list(0, 0.6)
	drift = generator(GEN_VECTOR, list(-0.1, 0), list(0.1, 0.05), UNIFORM_RAND)

/particles/artifact/psionic
	icon = 'icons/effects/particles/echo.dmi'
	icon_state = list("echo1" = 1, "echo2" = 1, "echo3" = 1)
	color = "#b86bff"
	spawning = 0.25
	lifespan = 2 SECONDS
	scale = generator(GEN_VECTOR, list(0.15, 0.15), list(0.3, 0.3), NORMAL_RAND)
	position = generator(GEN_CIRCLE, 0, 12, NORMAL_RAND)
	rotation = generator(GEN_NUM, 0, 360, UNIFORM_RAND)

/particles/artifact/electromagnetic
	icon_state = "cross"
	color = "#5fd3ff"
	spawning = 1.2
	lifespan = 0.4 SECONDS
	fade = 0.3 SECONDS
	fadein = 0
	position = generator(GEN_CIRCLE, 8, 15, UNIFORM_RAND)
	scale = generator(GEN_VECTOR, list(0.3, 0.3), list(0.6, 0.6), NORMAL_RAND)

/particles/artifact/particle
	color = "#e6efff"
	spawning = 0.5
	lifespan = 2.5 SECONDS
	velocity = list(0, 0.25)
	drift = generator(GEN_VECTOR, list(-0.15, 0), list(0.15, 0), UNIFORM_RAND)
	scale = generator(GEN_VECTOR, list(0.25, 0.25), list(0.5, 0.5), NORMAL_RAND)

/particles/artifact/organic
	icon_state = "drop"
	color = "#ff5f7a"
	spawning = 0.3
	lifespan = 1.2 SECONDS
	gravity = list(0, -0.3)
	position = generator(GEN_CIRCLE, 0, 9, NORMAL_RAND)

/particles/artifact/bluespace
	icon = 'icons/effects/particles/echo.dmi'
	icon_state = list("echo1" = 3, "echo2" = 1, "echo3" = 1)
	color = "#4a6bff"
	spawning = 1
	lifespan = 0.6 SECONDS
	fade = 0.5 SECONDS
	friction = 0.5
	position = generator(GEN_SPHERE, 4, 12, NORMAL_RAND)
	drift = generator(GEN_VECTOR, list(-1, 1), list(1, 2), NORMAL_RAND)
	scale = 0.6

/particles/artifact/synthesis
	icon_state = "curl"
	color = "#7dff6a"
	spawning = 0.4
	lifespan = 1.8 SECONDS
	velocity = list(0, 0.4)
	spin = generator(GEN_NUM, -20, 20, NORMAL_RAND)
