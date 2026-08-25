/**
 * # Drug lab ruin template
 *
 * The hidden kitchen for the drug smuggling mission. unpickable keeps it out
 * of natural seeding and replacement respawns (the rare_space.dm pattern).
 * The only road to one is an active drug run raising it at mission start
 * (see mission.dm, spawn_lab_ruin()).
 */
/datum/map_template/ruin/space/drug_lab
	id = "drug_lab"
	prefix = "_maps/voidcrew/RandomRuins/SpaceRuins/"
	suffix = "drug_lab.dmm"
	name = "Duster's Kitchen"
	description = "A clandestine drug lab, mothballed between cooks: reactors drained, hoppers scrubbed, the whole rig parked dark on an unlisted orbit. The equipment still works. All it needs is a crew with a formula and bad judgment."
	unpickable = TRUE
	allow_duplicates = FALSE
