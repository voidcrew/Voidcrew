// Debug verbs for trying out limb rig physics. Nothing in the game turns physics on by itself yet.

ADMIN_VERB(spawn_physics_ragdoll, R_DEBUG, "Spawn Physics Ragdoll", "Spawns a test dummy whose limb rig is driven by Box2D instead of its animations.", ADMIN_CATEGORY_DEBUG)
	if(!vcphys_available())
		to_chat(user, span_warning("The physics library (vcphys) isn't loaded. It goes next to the game, like rust_g."), confidential = TRUE)
		return
	var/static/list/species_choices = list(
		"Experiment" = /datum/species/experiment,
		"Milkie" = /datum/species/experiment/milkie,
		"Human" = /datum/species/human,
		"Felinid" = /datum/species/human/felinid,
		"Lizard" = /datum/species/lizard,
		"Moth" = /datum/species/moth,
		"Ethereal" = /datum/species/ethereal,
		"Plasmaman" = /datum/species/plasmaman,
	)
	var/choice = tgui_input_list(user, "What kind of body?", "Physics ragdoll", species_choices)
	if(!choice)
		return
	var/turf/spot = get_step(user.mob, user.mob.dir) || get_turf(user.mob)
	var/mob/living/carbon/human/dummy = new(spot)
	dummy.set_species(species_choices[choice])
	dummy.fully_replace_character_name(dummy.real_name, "ragdoll test dummy")
	dummy.setDir(EAST)
	// The rig is put together a moment after a mob is made.
	addtimer(CALLBACK(dummy, TYPE_PROC_REF(/mob/living/carbon, set_limb_physics), TRUE), 0.5 SECONDS)
	to_chat(user, span_notice("Spawned a [choice] ragdoll. Right-click it for Limb Physics: Push, Toggle and Inspect."), confidential = TRUE)
	log_admin("[key_name(user)] spawned a physics ragdoll at [AREACOORD(spot)].")
	BLACKBOX_LOG_ADMIN_VERB("Spawn Physics Ragdoll")

ADMIN_VERB_AND_CONTEXT_MENU(toggle_limb_physics, R_DEBUG, "Limb Physics: Toggle", "Turns Box2D physics on or off for a mob's limb rig.", ADMIN_CATEGORY_DEBUG, mob/living/carbon/target in world)
	// The context menu offers it on any mob.
	if(!iscarbon(target))
		to_chat(user, span_warning("[target] has no limb rig."), confidential = TRUE)
		return
	var/on = target.set_limb_physics(!target.limb_rig?.physics)
	if(!on && !target.limb_rig?.physics && !istype(target.limb_rig, /datum/limb_rig/sprites))
		to_chat(user, span_warning("[target] has no sprite-built limb rig to simulate."), confidential = TRUE)
		return
	to_chat(user, span_notice("Limb physics on [target]: [on ? "on" : "off"]."), confidential = TRUE)
	log_admin("[key_name(user)] turned limb physics [on ? "on" : "off"] for [key_name(target)].")

ADMIN_VERB_AND_CONTEXT_MENU(push_limb_physics, R_DEBUG, "Limb Physics: Push", "Gives one of a ragdoll's segments an impulse or a spin.", ADMIN_CATEGORY_DEBUG, mob/living/carbon/target in world)
	// The context menu offers it on any mob.
	if(!iscarbon(target))
		to_chat(user, span_warning("[target] has no limb rig."), confidential = TRUE)
		return
	var/datum/limb_physics/physics = target.limb_rig?.physics
	if(!physics)
		to_chat(user, span_warning("[target] isn't physical. Toggle limb physics on first."), confidential = TRUE)
		return
	var/part_id = tgui_input_list(user, "Which segment?", "Push", physics.body_by_part, RIG_CHEST)
	if(!part_id)
		return
	var/static/list/pushes = list("Shove right", "Shove left", "Launch up", "Slam down", "Spin clockwise", "Spin counter-clockwise")
	var/kind = tgui_input_list(user, "What kind of push?", "Push", pushes)
	if(!kind)
		return
	// Newton-seconds (or for a spin, newton-metre-seconds). A torso is about 15 kg.
	var/strength = tgui_input_number(user, "How hard? 10 is a nudge, 40 a shove, 100 a car.", "Push", 40, 500, 0.1, round_value = FALSE)
	if(!strength || QDELETED(physics))
		return
	switch(kind)
		if("Shove right")
			physics.push(part_id, strength, 0)
		if("Shove left")
			physics.push(part_id, -strength, 0)
		if("Launch up")
			physics.push(part_id, 0, strength)
		if("Slam down")
			physics.push(part_id, 0, -strength)
		if("Spin clockwise")
			physics.twist(part_id, -strength / 10)
		if("Spin counter-clockwise")
			physics.twist(part_id, strength / 10)

ADMIN_VERB_AND_CONTEXT_MENU(inspect_limb_physics, R_DEBUG, "Limb Physics: Inspect", "Shows a ragdoll's simulation: every body, and the last calls made to the library.", ADMIN_CATEGORY_DEBUG, mob/living/carbon/target in world)
	// The context menu offers it on any mob.
	if(!iscarbon(target))
		to_chat(user, span_warning("[target] has no limb rig."), confidential = TRUE)
		return
	var/datum/limb_physics/physics = target.limb_rig?.physics
	var/list/lines = list("<b>Limb physics: [target]</b>")
	lines += "Library: [vcphys_available() ? "[GLOB.vcphys_library] ([vcphys_call("version")])" : "not loaded"]"
	if(physics)
		lines += "World [physics.world_handle] ([vcphys_call("world_stats", physics.world_handle)]), facing [dir2text(physics.facing)], [physics.steps] steps ([physics.steps * LIMB_PHYSICS_DT] s simulated)."
		lines += "<table><tr><th>segment</th><th>body</th><th>x (m)</th><th>y (m)</th><th>angle (deg)</th><th>speed (m/s)</th></tr>"
		for(var/part_id in physics.body_by_part)
			var/handle = physics.body_by_part[part_id]
			var/list/state = physics.last_states?["[handle]"]
			if(state)
				lines += "<tr><td>[part_id]</td><td>[handle]</td><td>[round(state[1], 0.01)]</td><td>[round(state[2], 0.01)]</td><td>[round(TODEGREES(state[3]), 0.1)]</td><td>[round(sqrt(state[4] ** 2 + state[5] ** 2), 0.01)]</td></tr>"
			else
				lines += "<tr><td>[part_id]</td><td>[handle]</td><td colspan=4>not read yet</td></tr>"
		lines += "</table>"
	else
		lines += "Not physical."
	lines += "Call log: [GLOB.vcphys_logging ? "on" : "off"] (toggle with Limb Physics: Toggle Call Log)"
	for(var/entry in GLOB.vcphys_log)
		lines += "<tt>[html_encode(entry)]</tt>"
	var/datum/browser/popup = new(user.mob, "limb_physics", "Limb physics", 640, 520)
	popup.set_content(jointext(lines, "<br>"))
	popup.open()

ADMIN_VERB(toggle_limb_physics_log, R_DEBUG, "Limb Physics: Toggle Call Log", "Keeps (or stops keeping) the last calls made to the physics library, to read in Limb Physics: Inspect.", ADMIN_CATEGORY_DEBUG)
	GLOB.vcphys_logging = !GLOB.vcphys_logging
	if(!GLOB.vcphys_logging)
		GLOB.vcphys_log.Cut()
	to_chat(user, span_notice("Physics call log [GLOB.vcphys_logging ? "on" : "off"]."), confidential = TRUE)
