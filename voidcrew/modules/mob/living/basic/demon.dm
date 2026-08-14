/**
 * Feral demons: AI-driven variants for map placement.
 *
 * The base /mob/living/basic/demon is a player-controlled wizard summon and has no
 * ai_controller, so a bare map placement stands still and lets itself be looted.
 * Ruins must place these subtypes instead.
 */
/mob/living/basic/demon/feral
	ai_controller = /datum/ai_controller/basic_controller/simple/simple_hostile_obstacles

/mob/living/basic/demon/slaughter/feral
	ai_controller = /datum/ai_controller/basic_controller/simple/simple_hostile_obstacles
