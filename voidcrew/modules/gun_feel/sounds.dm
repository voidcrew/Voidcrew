// Gun sounds: powder guns play at their recorded pitch, our stock shots and handling sounds are swapped
// for Shiptest's fuller recordings by gun class, and the sound sets for bullet impacts and near misses
// (used in impacts.dm). The recordings come from Shiptest (shiptest-ss13/Shiptest); sources and
// licences are in sound/attribution.txt next to them.

// ---- Pitch ----

// Shiptest's powder guns never shift pitch, and with only a few recordings per class a random 0.73x-1.25x
// made half of our shots sound thin. The low-ammo click keeps its rising pitch (VOIDCREW EDITs in
// ballistic.dm and revolver.dm pass it vary = TRUE itself).
/obj/item/gun/ballistic
	vary_fire_sound = FALSE

/// Playback speed for one shot of a gun that still varies its pitch (energy weapons): a narrow spread
/// around the recording's own rate. Called from a VOIDCREW EDIT in energy.dm. Null plays it as recorded.
/obj/item/gun/proc/gun_feel_fire_frequency()
	if(!vary_fire_sound)
		return null
	return GUN_FEEL_PITCH(GUN_FEEL_ENERGY_PITCH_SPREAD)

// ---- Swapping in Shiptest's recordings ----

/// Our stock ballistic shots, by file path, and the Shiptest recording that replaces each.
/// Our shot files are already named by gun class, so this is a class-to-class swap.
GLOBAL_LIST_INIT(gun_feel_fire_sounds, list(
	"sound/items/weapons/gun/pistol/shot.ogg" = 'voidcrew/modules/gun_feel/sound/pistol/shot.ogg',
	"sound/items/weapons/gun/pistol/shot_alt.ogg" = 'voidcrew/modules/gun_feel/sound/pistol/shot_alt.ogg',
	"sound/items/weapons/gun/revolver/shot.ogg" = 'voidcrew/modules/gun_feel/sound/revolver/shot_light.ogg',
	"sound/items/weapons/gun/revolver/shot_alt.ogg" = 'voidcrew/modules/gun_feel/sound/revolver/shot.ogg',
	"sound/items/weapons/gun/smg/shot.ogg" = 'voidcrew/modules/gun_feel/sound/smg/shot.ogg',
	"sound/items/weapons/gun/smg/shot_alt.ogg" = 'voidcrew/modules/gun_feel/sound/rifle/shot.ogg',
	"sound/items/weapons/gun/rifle/shot.ogg" = 'voidcrew/modules/gun_feel/sound/rifle/shot.ogg',
	"sound/items/weapons/gun/shotgun/shot.ogg" = 'voidcrew/modules/gun_feel/sound/shotgun/shot.ogg',
	"sound/items/weapons/gun/sniper/shot.ogg" = 'voidcrew/modules/gun_feel/sound/sniper/shot.ogg',
	"sound/items/weapons/gun/l6/shot.ogg" = 'voidcrew/modules/gun_feel/sound/l6/shot.ogg',
))

/// Per gun class, our shared magazine and rack sounds and the class's own Shiptest handling sound.
/// Classes not listed (pistols, revolvers, shotguns, bolt rifles) already have their own handling sounds.
GLOBAL_LIST_INIT(gun_feel_handling_sounds, list(
	GUN_FEEL_CLASS_SMG = list(
		"sound/items/weapons/gun/general/magazine_insert_full.ogg" = 'voidcrew/modules/gun_feel/sound/smg/smg_reload.ogg',
		"sound/items/weapons/gun/general/magazine_insert_empty.ogg" = 'voidcrew/modules/gun_feel/sound/smg/smg_reload.ogg',
		"sound/items/weapons/gun/general/magazine_remove_full.ogg" = 'voidcrew/modules/gun_feel/sound/smg/smg_unload.ogg',
		"sound/items/weapons/gun/general/magazine_remove_empty.ogg" = 'voidcrew/modules/gun_feel/sound/smg/smg_unload.ogg',
	),
	GUN_FEEL_CLASS_RIFLE = list(
		"sound/items/weapons/gun/general/magazine_insert_full.ogg" = 'voidcrew/modules/gun_feel/sound/rifle/ar_reload.ogg',
		"sound/items/weapons/gun/general/magazine_insert_empty.ogg" = 'voidcrew/modules/gun_feel/sound/rifle/ar_reload.ogg',
		"sound/items/weapons/gun/general/magazine_remove_full.ogg" = 'voidcrew/modules/gun_feel/sound/rifle/ar_unload.ogg',
		"sound/items/weapons/gun/general/magazine_remove_empty.ogg" = 'voidcrew/modules/gun_feel/sound/rifle/ar_unload.ogg',
		"sound/items/weapons/gun/smg/smgrack.ogg" = 'voidcrew/modules/gun_feel/sound/rifle/ar_cock.ogg',
	),
	GUN_FEEL_CLASS_HEAVY = list(
		"sound/items/weapons/gun/general/magazine_insert_full.ogg" = 'voidcrew/modules/gun_feel/sound/hmg/cm40_reload.ogg',
		"sound/items/weapons/gun/general/magazine_insert_empty.ogg" = 'voidcrew/modules/gun_feel/sound/hmg/cm40_reload.ogg',
		"sound/items/weapons/gun/general/magazine_remove_full.ogg" = 'voidcrew/modules/gun_feel/sound/hmg/cm40_unload.ogg',
		"sound/items/weapons/gun/general/magazine_remove_empty.ogg" = 'voidcrew/modules/gun_feel/sound/hmg/cm40_unload.ogg',
	),
))

/// Returns the replacement for `current` from `swaps` (keyed by file path), or `current` if it has none.
/// Anything a gun sets for itself (smartgun, launchers, lasers in a magazine...) is not in the table and stays.
/proc/gun_feel_swap_sound(current, list/swaps)
	if(isnull(current) || !length(swaps))
		return current
	var/replacement = swaps["[current]"]
	return isnull(replacement) ? current : replacement

/obj/item/gun/ballistic/Initialize(mapload)
	. = ..()
	gun_feel_swap_sounds()

/// Swaps this gun's stock shot and handling sounds for its class's Shiptest ones.
/obj/item/gun/ballistic/proc/gun_feel_swap_sounds()
	var/list/fire_swaps = GLOB.gun_feel_fire_sounds
	fire_sound = gun_feel_swap_sound(fire_sound, fire_swaps)
	// Guns that rechamber for another caliber put one of these back when they switch.
	initial_fire_sound = gun_feel_swap_sound(initial_fire_sound, fire_swaps)
	alternative_fire_sound = gun_feel_swap_sound(alternative_fire_sound, fire_swaps)
	// Only reads the class: kick values stay unresolved until the first shot, as before.
	var/sound_class = gun_feel_class || gun_feel_pick_class()
	var/list/handling_swaps = GLOB.gun_feel_handling_sounds[sound_class]
	if(!handling_swaps)
		return
	load_sound = gun_feel_swap_sound(load_sound, handling_swaps)
	load_empty_sound = gun_feel_swap_sound(load_empty_sound, handling_swaps)
	eject_sound = gun_feel_swap_sound(eject_sound, handling_swaps)
	eject_empty_sound = gun_feel_swap_sound(eject_empty_sound, handling_swaps)
	rack_sound = gun_feel_swap_sound(rack_sound, handling_swaps)

// NPCs that shoot through the ranged attack component (pirates, troopers) use the same recordings as
// the player guns of their class.
/datum/component/ranged_attacks/Initialize(
	casing_type,
	projectile_type,
	projectile_sound = 'sound/items/weapons/gun/pistol/shot.ogg',
	burst_shots,
	burst_intervals = 0.2 SECONDS,
	cooldown_time = 3 SECONDS,
)
	. = ..()
	if(. == COMPONENT_INCOMPATIBLE)
		return
	src.projectile_sound = gun_feel_swap_sound(src.projectile_sound, GLOB.gun_feel_fire_sounds)

// ---- Sound sets for impacts and near misses ----

/// A bullet hitting flesh. Shiptest's bullet_hit set.
/datum/sound_effect/gun_feel_bullet_flesh
	key = SFX_GUN_FEEL_BULLET_FLESH
	file_paths = list(
		'voidcrew/modules/gun_feel/sound/hit/bullet_impact1.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_impact2.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_impact3.ogg',
	)

/// A bullet passing close by.
/datum/sound_effect/gun_feel_bullet_miss
	key = SFX_GUN_FEEL_BULLET_MISS
	file_paths = list(
		'voidcrew/modules/gun_feel/sound/hit/bullet_miss1.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_miss2.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_miss3.ogg',
	)

/datum/sound_effect/gun_feel_hit_metal
	key = SFX_GUN_FEEL_HIT_METAL
	file_paths = list(
		'voidcrew/modules/gun_feel/sound/hit/bullet_metal_01.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_metal_02.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_metal_03.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_metal_04.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_metal_05.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_metal_06.ogg',
	)

/datum/sound_effect/gun_feel_hit_glass
	key = SFX_GUN_FEEL_HIT_GLASS
	file_paths = list(
		'voidcrew/modules/gun_feel/sound/hit/bullet_glass_01.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_glass_02.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_glass_03.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_glass_04.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_glass_05.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_glass_06.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_glass_07.ogg',
	)

/datum/sound_effect/gun_feel_hit_stone
	key = SFX_GUN_FEEL_HIT_STONE
	file_paths = list(
		'voidcrew/modules/gun_feel/sound/hit/bullet_masonry_01.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_masonry_02.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_masonry_03.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_masonry_04.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_masonry_05.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_masonry_06.ogg',
	)

/datum/sound_effect/gun_feel_hit_wood
	key = SFX_GUN_FEEL_HIT_WOOD
	file_paths = list(
		'voidcrew/modules/gun_feel/sound/hit/bullet_wood_01.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_wood_02.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_wood_03.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_wood_04.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_wood_05.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_wood_06.ogg',
	)

/datum/sound_effect/gun_feel_hit_snow
	key = SFX_GUN_FEEL_HIT_SNOW
	file_paths = list(
		'voidcrew/modules/gun_feel/sound/hit/bullet_snow_01.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_snow_02.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_snow_03.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_snow_04.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_snow_05.ogg',
		'voidcrew/modules/gun_feel/sound/hit/bullet_snow_06.ogg',
	)
