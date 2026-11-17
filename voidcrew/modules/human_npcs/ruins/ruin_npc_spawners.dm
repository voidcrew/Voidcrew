// Map spawners for the ruin, planet and mission human NPCs. Each one queues its NPC when the map loads
// (spawn_human_npc(), a body per tick), dressed for the zone the ruin landed in. Set npc_name or
// npc_faction on a placed spawner for one NPC's own name or side (a camp's private faction).

// ===== Pirates =====

/obj/effect/spawner/human_npc/ruin/pirate
	name = "pirate swashbuckler spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/pirate

/obj/effect/spawner/human_npc/ruin/pirate/gunner
	name = "pirate gunner spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/pirate/gunner

/obj/effect/spawner/human_npc/ruin/pirate/space
	name = "space pirate swashbuckler spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/pirate/space

/obj/effect/spawner/human_npc/ruin/pirate/space/gunner
	name = "space pirate gunner spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/pirate/space/gunner

/obj/effect/spawner/human_npc/ruin/pirate/beach
	name = "beach pirate swashbuckler spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/pirate/beach

/obj/effect/spawner/human_npc/ruin/pirate/beach/gunner
	name = "beach pirate gunner spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/pirate/beach/gunner

/obj/effect/spawner/human_npc/ruin/pirate/cosplayer
	name = "pirate cosplayer spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/pirate/cosplayer

// ===== Syndicate =====

/obj/effect/spawner/human_npc/ruin/syndicate
	name = "Syndicate operative spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/syndicate

/obj/effect/spawner/human_npc/ruin/syndicate/sword
	name = "Syndicate sword guard spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/syndicate/sword

/obj/effect/spawner/human_npc/ruin/syndicate/gunner
	name = "Syndicate gunner spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/syndicate/gunner

/obj/effect/spawner/human_npc/ruin/syndicate/gunner/smg
	name = "Syndicate SMG gunner spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/syndicate/gunner/smg

/obj/effect/spawner/human_npc/ruin/syndicate/gunner/shotgun
	name = "Syndicate shotgunner spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/syndicate/gunner/shotgun

/obj/effect/spawner/human_npc/ruin/syndicate/gunner/pilot
	name = "Syndicate salvage pilot spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/syndicate/gunner/pilot

/obj/effect/spawner/human_npc/ruin/syndicate/commando
	name = "Syndicate commando spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/syndicate/commando

/obj/effect/spawner/human_npc/ruin/syndicate/commando/gunner
	name = "Syndicate commando gunner spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/syndicate/commando/gunner

/obj/effect/spawner/human_npc/ruin/syndicate/commando/smg
	name = "Syndicate commando SMG gunner spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/syndicate/commando/smg

/obj/effect/spawner/human_npc/ruin/syndicate/stormtrooper
	name = "Syndicate stormtrooper spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/syndicate/stormtrooper

/obj/effect/spawner/human_npc/ruin/syndicate/stormtrooper/shotgun
	name = "Syndicate stormtrooper shotgunner spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/syndicate/stormtrooper/shotgun

/obj/effect/spawner/human_npc/ruin/syndicate/stormtrooper/sword
	name = "Syndicate stormtrooper sword guard spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/syndicate/stormtrooper/sword

// ===== Nanotrasen and Russians =====

/obj/effect/spawner/human_npc/ruin/nanotrasen
	name = "Nanotrasen security officer spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/nanotrasen

/obj/effect/spawner/human_npc/ruin/russian
	name = "Russian mobster spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/russian

/obj/effect/spawner/human_npc/ruin/russian/gunner
	name = "Russian gunner spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/russian/gunner

// ===== Hermits =====

/obj/effect/spawner/human_npc/ruin/hermit
	name = "hermit wanderer spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/hermit

/obj/effect/spawner/human_npc/ruin/hermit/hunter
	name = "hermit hunter spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/hermit/hunter

/obj/effect/spawner/human_npc/ruin/hermit/gunslinger
	name = "hermit soldier spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/hermit/gunslinger
