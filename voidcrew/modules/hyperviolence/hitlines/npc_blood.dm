// Hyperviolence: NPCs that bleed.
//
// Basic and simple mobs start with blood_volume 0, so a shot or a blow on them leaves nothing on the
// floor and nothing on the attacker. Organic NPCs are given blood on spawn, and an overlay that
// gets bloodier as their health falls.
//
// Blood cannot hurt them: only wounds, dismemberment and a few items on carbon mobs ever call
// bleed(), and handle_blood() (oxygen loss from thin blood) is human-only, so a basic mob's blood
// is only ever read, to colour decals and splatter.
//
// The overlay art, icons/npc_blood.dmi, is adapted from Aurora.3 icons/mob/npc/blood_overlay.dmi
// (Aurorastation/Aurora.3 commit 82a514d97b07, CC BY-SA 3.0): the three states are recoloured white
// so the mob's own blood colour fills them. The overlay idea follows Aurora's simple_animal
// handle_blood(); this code is new.

/// Overlay stages, by how much of its health the mob has left
#define HV_NPC_BLOOD_NONE 0
#define HV_NPC_BLOOD_LIGHT 1
#define HV_NPC_BLOOD_MEDIUM 2
#define HV_NPC_BLOOD_HEAVY 3

/// At or below this share of its health a mob shows light blood
#define HV_NPC_BLOOD_LIGHT_AT 0.75
/// At or below this share of its health a mob shows medium blood
#define HV_NPC_BLOOD_MEDIUM_AT 0.5
/// At or below this share of its health a mob shows heavy blood
#define HV_NPC_BLOOD_HEAVY_AT 0.25

/// Source of the keep-together flag the inset blood needs
#define HV_NPC_BLOOD_SOURCE "hv_npc_blood"

/mob/living
	/// Which blood overlay stage this NPC shows right now (HV_NPC_BLOOD_*). Only moved by /datum/element/hv_npc_blood.
	var/hv_blood_stage = HV_NPC_BLOOD_NONE

/// Gives an organic basic or simple mob blood and the overlay that shows its wounds.
/mob/living/proc/hv_setup_npc_blood()
	if(QDELETED(src) || HAS_TRAIT(src, TRAIT_NOBLOOD))
		return
	if(!blood_volume)
		if(!hv_npc_default_bleeder())
			return
		blood_volume = BLOOD_VOLUME_NORMAL
	else if(!hv_npc_shows_blood())
		return
	AddElement(/datum/element/hv_npc_blood)

/// True for an organic body with blood to show: no machine, spirit, plant, slime, rock or undead thing.
/mob/living/proc/hv_npc_shows_blood()
	if(!(mob_biotypes & MOB_ORGANIC))
		return FALSE
	return !(mob_biotypes & (MOB_ROBOTIC|MOB_UNDEAD|MOB_SPIRIT|MOB_MINERAL|MOB_PLANT|MOB_SLIME))

/// True for a mob that should bleed without having been given blood by hand. Bosses and other special
/// things keep what they have, and a mob only counts as a creature if it says what kind it is
/// or is one of the few plain organic animals and people listed here.
/mob/living/proc/hv_npc_default_bleeder()
	if(!hv_npc_shows_blood() || (mob_biotypes & MOB_SPECIAL))
		return FALSE
	if(mob_biotypes & (MOB_HUMANOID|MOB_BEAST|MOB_BUG|MOB_REPTILE|MOB_AQUATIC|MOB_CRUSTACEAN))
		return TRUE
	var/static/list/plain_bleeders = typecacheof(list(
		/mob/living/basic/parrot,
		/mob/living/basic/regal_rat,
		/mob/living/basic/snail,
		/mob/living/basic/stoat,
	))
	return is_type_in_typecache(src, plain_bleeders)

/mob/living/basic/Initialize(mapload)
	. = ..()
	hv_setup_npc_blood()

/mob/living/simple_animal/Initialize(mapload)
	. = ..()
	hv_setup_npc_blood()

/// Overlays a mob with blood as its health falls: light, medium, then heavy. Gone when it is healed.
/datum/element/hv_npc_blood

/datum/element/hv_npc_blood/Attach(datum/target)
	. = ..()
	if(!isliving(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_LIVING_HEALTH_UPDATE, PROC_REF(on_health_update))
	RegisterSignal(target, COMSIG_ATOM_UPDATE_OVERLAYS, PROC_REF(on_update_overlays))
	on_health_update(target)

/datum/element/hv_npc_blood/Detach(mob/living/host)
	UnregisterSignal(host, list(COMSIG_LIVING_HEALTH_UPDATE, COMSIG_ATOM_UPDATE_OVERLAYS))
	if(host.hv_blood_stage != HV_NPC_BLOOD_NONE)
		host.hv_blood_stage = HV_NPC_BLOOD_NONE
		REMOVE_KEEP_TOGETHER(host, HV_NPC_BLOOD_SOURCE)
		if(!QDELETED(host))
			host.update_appearance(UPDATE_OVERLAYS)
	return ..()

/// How bloody a mob with this much health left should look
/datum/element/hv_npc_blood/proc/stage_for(mob/living/source)
	if(source.maxHealth <= 0)
		return HV_NPC_BLOOD_NONE
	var/health_share = source.health / source.maxHealth
	if(health_share <= HV_NPC_BLOOD_HEAVY_AT)
		return HV_NPC_BLOOD_HEAVY
	if(health_share <= HV_NPC_BLOOD_MEDIUM_AT)
		return HV_NPC_BLOOD_MEDIUM
	if(health_share <= HV_NPC_BLOOD_LIGHT_AT)
		return HV_NPC_BLOOD_LIGHT
	return HV_NPC_BLOOD_NONE

/datum/element/hv_npc_blood/proc/on_health_update(mob/living/host)
	SIGNAL_HANDLER

	var/stage = stage_for(host)
	if(stage == host.hv_blood_stage)
		return
	// The blood is cut to the mob's own shape, which only works when the mob is drawn as one group
	if(host.hv_blood_stage == HV_NPC_BLOOD_NONE)
		ADD_KEEP_TOGETHER(host, HV_NPC_BLOOD_SOURCE)
	else if(stage == HV_NPC_BLOOD_NONE)
		REMOVE_KEEP_TOGETHER(host, HV_NPC_BLOOD_SOURCE)
	host.hv_blood_stage = stage
	host.update_appearance(UPDATE_OVERLAYS)

/datum/element/hv_npc_blood/proc/on_update_overlays(mob/living/source, list/overlays)
	SIGNAL_HANDLER

	if(source.hv_blood_stage == HV_NPC_BLOOD_NONE)
		return
	var/blood_color = source.get_bloodtype()?.get_color()
	if(isnull(blood_color))
		return
	var/state
	switch(source.hv_blood_stage)
		if(HV_NPC_BLOOD_LIGHT)
			state = "light"
		if(HV_NPC_BLOOD_MEDIUM)
			state = "medium"
		else
			state = "heavy"
	var/mutable_appearance/blood = mutable_appearance('voidcrew/modules/hyperviolence/hitlines/icons/npc_blood.dmi', state, appearance_flags = RESET_COLOR)
	blood.blend_mode = BLEND_INSET_OVERLAY
	blood.color = blood_color
	// The art is one tile: stretch it over a sprite that is bigger than that
	var/width = source.get_cached_width()
	var/height = source.get_cached_height()
	if(width > ICON_SIZE_X || height > ICON_SIZE_Y)
		var/matrix/stretch = matrix()
		stretch.Scale(max(width, ICON_SIZE_X) / ICON_SIZE_X, max(height, ICON_SIZE_Y) / ICON_SIZE_Y)
		stretch.Translate((max(width, ICON_SIZE_X) - ICON_SIZE_X) / 2, (max(height, ICON_SIZE_Y) - ICON_SIZE_Y) / 2)
		blood.transform = stretch
	overlays += blood

#undef HV_NPC_BLOOD_SOURCE
#undef HV_NPC_BLOOD_HEAVY_AT
#undef HV_NPC_BLOOD_MEDIUM_AT
#undef HV_NPC_BLOOD_LIGHT_AT
