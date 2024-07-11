/mob/living/basic/spider/giant/tarantula/wasteland
	faction = list(FACTION_WASTELAND)
/mob/living/basic/spider/giant/wasteland
	faction = list(FACTION_WASTELAND)

/mob/living/basic/spider/giant/wasteland/Initialize(mapload)
	. = ..()
	ai_controller.set_blackboard_key(BB_SPIDER_WEB_ACTION, null)

/mob/living/basic/spider/giant/tarantula/wasteland/Initialize(mapload)
	. = ..()
	ai_controller.set_blackboard_key(BB_SPIDER_WEB_ACTION, null)
