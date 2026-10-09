/**
 * Everything on a rhythm battle's stage besides the two singers singing:
 * - The girlfriend (or Nene), summoned to stand behind them, bopping to the beat and cheering. In
 *   Stress she's Pico (or Otis) up on the speaker, gunning down the tankmen who run at the stage
 *   from both sides, on the song's own speaker track. Week 4 brings Mommy's henchmen, dancing.
 * - The song's lyrics, where it has them, under the stage.
 * - Chart events that have someone do something: Boyfriend's "hey!", Tankman's "ugh", Pico's
 *   burp.
 * - Notes that are a move rather than a line. Tankman's "ugh" notes, and all of Weekend 1: in
 *   2hot Darnell lights cans and kicks them up for Pico to shoot, and Blazin' is a fistfight, every
 *   note a punch, block or dodge.
 * - What the song's stage does. Week 2's mansion gets struck by lightning, scaring everyone; Week 3's
 *   train comes rumbling past. Week 6 opens with its dialogue, and Darnell with Darnell lighting a
 *   can for Pico to shoot.
 */
/datum/fnf_stage
	var/datum/fnf_battle/battle
	/// Whoever's cheering from the back, summoned for the song.
	var/mob/living/carbon/human/girlfriend
	/// Whoever the player carries through the song (Stress: Girlfriend, or Nene clinging to Pico).
	var/mob/living/carbon/human/carried
	/// Until when the girlfriend's busy (shooting), and shouldn't bop.
	var/girlfriend_busy_until = 0
	/// Which way whoever's in the girlfriend's place faces: the front, or round at someone.
	var/girlfriend_facing = SOUTH
	/// Week 4's backup dancers.
	var/list/mob/living/carbon/human/henchmen = list()
	/// Stress's tankmen: every one made so far, and the ones free to run in again.
	var/list/mob/living/carbon/human/soldiers = list()
	var/list/mob/living/carbon/human/idle_soldiers = list()
	/// The next shot on the speaker track to send a tankman in for.
	var/next_shot = 1
	/// Where the singers stand, for the tankmen to run at.
	var/turf/left_spot
	var/turf/right_spot
	/// The knife stuck in Tankman's head, and whose head it's in.
	var/image/head_knife
	var/atom/knifed
	/// The next line of the lyrics to show, and when the one showing ends (song ms).
	var/next_lyric = 1
	var/lyric_ends = -1
	var/obj/effect/abstract/fnf_hud/text/lyric_text
	/// The can in the air in 2hot, if there is one.
	var/obj/effect/abstract/fnf_hud/can
	/// How far apart the singers stand, in pixels.
	var/gap_px = 96
	/// Week 2's lightning: the beat it last struck on, and how many beats until it can again.
	var/lightning_beat = 0
	var/lightning_wait = 8
	/// Week 3's train: beats since it last passed, and whether it's passing now.
	var/train_cooldown = 0
	var/train_passing = FALSE
	/// Week 6's dialogue box before the song, and its lines still to come.
	var/obj/effect/abstract/fnf_hud/text/dialogue_text
	var/list/dialogue_lines
	var/dialogue_channel

/datum/fnf_stage/New(datum/fnf_battle/battle, turf/left_turf, turf/right_turf)
	src.battle = battle
	gap_px = (right_turf.x - left_turf.x) * world.icon_size
	left_spot = left_turf
	right_spot = right_turf
	summon_girlfriend(left_turf, right_turf)
	summon_carried(right_turf)
	if(battle.song.id in list("satin-panties", "high", "milf"))
		summon_henchmen(left_turf, right_turf)
	if(length(battle.song.lyrics) && battle.healthbar)
		lyric_text = new
		lyric_text.maptext_width = 256
		lyric_text.maptext_x = -112
		lyric_text.layer = ABOVE_ALL_MOB_LAYER + 0.05
		lyric_text.pixel_w = battle.healthbar.center_x - 16
		lyric_text.pixel_z = battle.healthbar.center_y - FNF_STRUM_Y - 44 - 30
		battle.healthbar.vis_contents += lyric_text
	start_intro()

/datum/fnf_stage/Destroy()
	QDEL_NULL(seat)
	QDEL_LIST_ASSOC_VAL(singer_props)
	if(girlfriend && !QDELETED(girlfriend))
		do_sparks(2, FALSE, girlfriend)
		qdel(girlfriend)
	girlfriend = null
	if(carried && !QDELETED(carried))
		qdel(carried)
	carried = null
	QDEL_LIST(henchmen)
	for(var/mob/living/soldier as anything in soldiers)
		GLOB.move_manager.stop_looping(soldier)
	QDEL_LIST(soldiers)
	idle_soldiers.Cut()
	if(knifed && head_knife)
		knifed.cut_overlay(head_knife)
	knifed = null
	head_knife = null
	battle?.healthbar?.vis_contents -= lyric_text
	QDEL_NULL(lyric_text)
	battle?.healthbar?.vis_contents -= dialogue_text
	QDEL_NULL(dialogue_text)
	QDEL_NULL(can)
	if(dialogue_channel)
		for(var/mob/listener as anything in battle?.listeners)
			SEND_SOUND(listener, sound(null, channel = dialogue_channel))
		SSsounds.free_datum_channels(src)
	battle = null
	return ..()

/// She stands a step behind, halfway between the singers, if there's room.
/datum/fnf_stage/proc/summon_girlfriend(turf/left_turf, turf/right_turf)
	summon_girlfriend_as(battle.song.girlfriend_character)

/// Summons someone to stand behind the singers, as one of the looks in opponents.dm.
/datum/fnf_stage/proc/summon_girlfriend_as(character)
	if(!GLOB.fnf_opponents[character])
		return
	var/turf/middle = get_girlfriend_spot()
	if(!middle || (locate(/mob/living) in middle))
		return
	girlfriend = fnf_summon_opponent(character, middle)
	var/speaker_shooter = length(battle.chart["speaker"])
	for(var/obj/item/held in girlfriend.held_items)
		if(!speaker_shooter || !istype(held, /obj/item/toy/fnf_gun))
			qdel(held)
	// Whoever's up on the speaker in Stress dual-wields: Pico two guns, Otis two rifles.
	if(speaker_shooter)
		var/gun_type = GLOB.fnf_opponents[character]["gun"]
		if(!ispath(gun_type))
			gun_type = /obj/item/toy/fnf_gun
		girlfriend.put_in_hands(new gun_type(girlfriend))
	girlfriend.setDir(SOUTH)
	do_sparks(2, FALSE, girlfriend)
	// Up on her speakers (Corruption+'s songs say what she's on themselves).
	if(!battle.song.corruption)
		var/list/seat_for = get_seat_for(character)
		set_seat(seat_for?[1], seat_for?[2])

/// In Stress, the player sings holding someone: Boyfriend carries Girlfriend, Nene clings to Pico's
/// back. They ride along on the player's tile, just behind them.
/datum/fnf_stage/proc/summon_carried(turf/right_turf)
	var/static/list/carried_by = list("bf-holding-gf" = "gf", "pico-holding-nene" = "nene")
	var/character = carried_by[battle.song.player_variant]
	if(!character || !battle.right?.singer)
		return
	carried = fnf_summon_opponent(character, right_turf)
	for(var/obj/item/held in carried.held_items)
		qdel(held)
	carried.setDir(battle.right.facing)
	// Behind the singer (who faces west), a little up off the floor, and drawn behind them.
	carried.pixel_w = battle.right.facing == WEST ? 7 : -7
	carried.pixel_z = 5
	carried.layer = battle.right.singer.layer - 0.01

/// Week 4: three of Mommy's henchmen dancing in a row behind the stage, where there's room.
/datum/fnf_stage/proc/summon_henchmen(turf/left_turf, turf/right_turf)
	for(var/spot_x in list(left_turf.x, round((left_turf.x + right_turf.x) / 2), right_turf.x))
		var/turf/spot = locate(spot_x, left_turf.y + 2, left_turf.z)
		if(!spot || spot.is_blocked_turf(exclude_mobs = FALSE))
			continue
		var/mob/living/carbon/human/henchman = fnf_summon_opponent("henchman", spot)
		for(var/obj/item/held in henchman.held_items)
			qdel(held)
		henchman.setDir(SOUTH)
		henchmen += henchman

/datum/fnf_stage/proc/bop(beat_time)
	if(girlfriend && !QDELETED(girlfriend) && world.time >= girlfriend_busy_until)
		// Corrupted Marble doesn't dance: she glares at the enemy.
		if(girlfriend.fnf_look == "marble")
			girlfriend.fnf_stare(beat_time, get_enemy_side(girlfriend))
		else
			girlfriend.setDir(girlfriend_facing)
			girlfriend.fnf_bop(beat_time, girlfriend_facing == SOUTH ? RIG_R_ARM : girlfriend.fnf_mic_arm(girlfriend_facing), girlfriend_facing, null)
	seat?.thump()
	for(var/mob/living/carbon/human/henchman as anything in henchmen)
		henchman.fnf_dance(beat_time, battle.last_beat % 2)
	if(carried && !QDELETED(carried))
		carried.fnf_bop(beat_time, RIG_R_ARM, battle.right.facing, null)
	var/beat = battle.last_beat
	switch(battle.song.id)
		if("spookeez", "south", "monster")
			// Struck at random, never twice within 8 to 24 beats. Spookeez opens with one, silent.
			if(beat == 4 && battle.song.id == "spookeez")
				lightning(FALSE)
			else if(beat > lightning_beat + lightning_wait && prob(10))
				lightning(TRUE)
		if("pico", "philly-nice", "blammed")
			// Now and then, on the middle of a bar, a train.
			if(!train_passing)
				train_cooldown++
				if(beat % 8 == 4 && train_cooldown > 8 && prob(30))
					train_cooldown = rand(-4, 0)
					pass_train()

/// Everyone listening: the singers, and anyone watching.
/datum/fnf_stage/proc/play_to_all(sound_file, volume = 60)
	for(var/mob/listener as anything in battle.listeners)
		SEND_SOUND(listener, sound(sound_file, volume = volume * (battle.listeners[listener] || 1)))

/// The mansion lit up by lightning: a flash, thunder, and Boyfriend and the girlfriend jumping.
/datum/fnf_stage/proc/lightning(with_thunder)
	lightning_beat = battle.last_beat
	lightning_wait = rand(8, 24)
	if(with_thunder)
		play_to_all("voidcrew/modules/fnf/sound/thunder[rand(1, 2)].ogg", 70)
	for(var/mob/listener as anything in battle.listeners)
		if(listener.client)
			flash_color(listener.client, "#dde8ff", 4)
	battle.right?.act("hit_high", 4)
	if(girlfriend && !QDELETED(girlfriend))
		girlfriend.fnf_act("hit_high", RIG_R_ARM, SOUTH, null, 4)

/// A train thunders past behind the stage: the rumble builds, the girlfriend's hair whips about as
/// it goes by, and it's gone.
/datum/fnf_stage/proc/pass_train()
	train_passing = TRUE
	play_to_all("voidcrew/modules/fnf/sound/train_passes.ogg", 55)
	addtimer(CALLBACK(src, PROC_REF(train_rushes)), 47, TIMER_DELETE_ME)
	addtimer(VARSET_CALLBACK(src, train_passing, FALSE), 90, TIMER_DELETE_ME)

/datum/fnf_stage/proc/train_rushes()
	for(var/mob/listener as anything in battle.listeners)
		shake_camera(listener, 12, 0.5)
	if(girlfriend && !QDELETED(girlfriend))
		girlfriend.fnf_act("dodge_high", RIG_R_ARM, SOUTH, null, 10)

/// What happens before the count in: Week 6's dialogue, or Darnell's can. Pushes the count in back
/// for as long as it takes.
/datum/fnf_stage/proc/start_intro()
	if(read_dialogue())
		return
	if(battle.song.id == "darnell" && !battle.song.variation)
		battle.lead_in += 4 SECONDS
		// He lights one, kicks it up, and Pico shoots it down. Darnell has a good laugh.
		addtimer(CALLBACK(src, PROC_REF(weekend_cans), null, "lightcan", TRUE), 5, TIMER_DELETE_ME)
		addtimer(CALLBACK(src, PROC_REF(weekend_cans), null, "kickcan", TRUE), 13, TIMER_DELETE_ME)
		addtimer(CALLBACK(src, PROC_REF(weekend_cans), null, "cockgun", TRUE), 18, TIMER_DELETE_ME)
		addtimer(CALLBACK(src, PROC_REF(weekend_cans), null, "firegun", TRUE), 24, TIMER_DELETE_ME)
		addtimer(CALLBACK(src, PROC_REF(darnell_laughs)), 29, TIMER_DELETE_ME)

/datum/fnf_stage/proc/darnell_laughs()
	battle.left?.act("taunt", 6)

/**
 * Week 6's dialogue, from data/fnf/dialogue/ (fetched with the songs): read the song's conversation
 * and start playing it in a box under the stage, one line after another, typed out to its music.
 * Returns TRUE if the song has one.
 */
/datum/fnf_stage/proc/read_dialogue()
	var/list/conversation = fnf_read_json("data/fnf/dialogue/[battle.song.id][battle.song.variation ? "-[battle.song.variation]" : ""].json")
	if(!length(conversation?["dialogue"]) || !battle.healthbar)
		return FALSE
	dialogue_lines = list()
	var/total = 0
	for(var/list/entry in conversation["dialogue"])
		var/text = jointext(entry["text"], " ")
		var/list/line = list(fnf_dialogue_speaker(entry["speaker"], battle), text)
		dialogue_lines += list(line)
		total += fnf_dialogue_line_time(text)
	battle.lead_in += total
	dialogue_text = new
	dialogue_text.maptext_width = 288
	dialogue_text.maptext_height = 64
	dialogue_text.maptext_x = -128
	dialogue_text.layer = ABOVE_ALL_MOB_LAYER + 0.07
	dialogue_text.pixel_w = battle.healthbar.center_x - 16
	dialogue_text.pixel_z = battle.healthbar.center_y - FNF_STRUM_Y - 44 - 64
	battle.healthbar.vis_contents += dialogue_text
	var/music = conversation["music"]?["asset"]
	if(music)
		dialogue_channel = SSsounds.reserve_sound_channel(src)
		var/music_file = music == "LunchboxScary" ? "voidcrew/modules/fnf/sound/dialogue_music_scary.ogg" : "voidcrew/modules/fnf/sound/dialogue_music.ogg"
		for(var/mob/listener as anything in battle.listeners)
			SEND_SOUND(listener, sound(music_file, repeat = TRUE, channel = dialogue_channel, volume = 35 * (battle.listeners[listener] || 1)))
	next_dialogue_line()
	return TRUE

/// How long a line of dialogue stays up, in deciseconds: typed out, then read.
/proc/fnf_dialogue_line_time(text)
	return round(length(text) * 0.35) + 20

/// Who's talking, as the box names them.
/proc/fnf_dialogue_speaker(speaker, datum/fnf_battle/battle)
	switch(fnf_base_character(speaker))
		if("senpai")
			return list("Senpai", "#ffb3d9")
		if("spirit")
			return list("Spirit", "#ff4a4a")
		if("nene")
			return list("Nene", "#ff8ad8")
		if("bf", "pico")
			return list(battle.right?.singer_name || "You", "#8ad8ff")
	return list(capitalize(speaker), "#ffffff")

/datum/fnf_stage/proc/next_dialogue_line()
	if(QDELETED(src) || !dialogue_text)
		return
	if(!length(dialogue_lines))
		battle.healthbar.vis_contents -= dialogue_text
		QDEL_NULL(dialogue_text)
		if(dialogue_channel)
			for(var/mob/listener as anything in battle.listeners)
				SEND_SOUND(listener, sound(null, channel = dialogue_channel))
		return
	var/list/line = dialogue_lines[1]
	dialogue_lines.Cut(1, 2)
	type_dialogue(line[1], line[2], 0)
	addtimer(CALLBACK(src, PROC_REF(next_dialogue_line)), fnf_dialogue_line_time(line[2]), TIMER_DELETE_ME)

/// Types a line out a few letters at a time, blipping as it goes.
/datum/fnf_stage/proc/type_dialogue(list/speaker, text, shown)
	if(QDELETED(src) || !dialogue_text)
		return
	shown = min(shown + 4, length(text))
	dialogue_text.maptext = MAPTEXT("<span style='font-size:7pt;-dm-text-outline:1px #000000'><b style='color:[speaker[2]]'>[html_encode(speaker[1])]</b><br><span style='color:#ffffff'>[html_encode(copytext(text, 1, shown + 1))]</span></span>")
	if(shown % 8 == 0)
		play_to_all("voidcrew/modules/fnf/sound/dialogue_blip.ogg", 30)
	if(shown < length(text))
		addtimer(CALLBACK(src, PROC_REF(type_dialogue), speaker, text, shown), 1.4, TIMER_DELETE_ME)

/// How long a tankman takes to run in, in song milliseconds.
#define FNF_SOLDIER_RUN_MS 1600
/// Most tankmen out at once, kept low: each is a whole rigged mob. Shots beyond that are just shots.
#define FNF_MAX_SOLDIERS 2

/// Sends in the tankmen the speaker is about to shoot.
/datum/fnf_stage/proc/send_soldiers(now)
	var/list/shots = battle.chart["speaker"]
	if(!length(shots) || !girlfriend || QDELETED(girlfriend))
		return
	while(next_shot <= length(shots))
		var/list/shot = shots[next_shot]
		if(shot[1] - FNF_SOLDIER_RUN_MS > now)
			break
		next_shot++
		if(shot[1] > now)
			send_soldier(shot[2] <= 1, shot[1] - now)

/// A tankman runs in from off one side, to be shot as he gets near the stage.
/datum/fnf_stage/proc/send_soldier(from_left, ms_left)
	var/turf/near = locate(from_left ? left_spot.x - 1 : right_spot.x + 1, left_spot.y, left_spot.z)
	var/turf/start = locate(from_left ? left_spot.x - 5 : right_spot.x + 5, left_spot.y, left_spot.z)
	if(!near || !start)
		return
	var/mob/living/carbon/human/soldier = get_soldier(start)
	if(!soldier)
		return
	soldier.forceMove(start)
	soldier.alpha = 255
	soldier.setDir(from_left ? EAST : WEST)
	// Running, strides timed to the pace he's moved at.
	var/delay = max(round(ms_left / 100 / 4, world.tick_lag), world.tick_lag)
	if(soldier.limb_rig)
		soldier.limb_rig.step_delay_override = delay
	GLOB.move_manager.move_to(soldier, near, 0, delay)
	addtimer(CALLBACK(src, PROC_REF(shoot_soldier), soldier, from_left), ms_left / 100, TIMER_DELETE_ME)

/// A tankman off the bench, or a new one if they're all out and there's room for another.
/datum/fnf_stage/proc/get_soldier(turf/where)
	if(length(idle_soldiers))
		var/mob/living/carbon/human/soldier = idle_soldiers[length(idle_soldiers)]
		idle_soldiers.len--
		return soldier
	if(length(soldiers) >= FNF_MAX_SOLDIERS)
		return null
	var/mob/living/carbon/human/soldier = new(where)
	soldier.fully_replace_character_name(soldier.real_name, "Tankman soldier")
	soldier.equipOutfit(/datum/outfit/fnf_soldier)
	if(soldier.move_intent != MOVE_INTENT_RUN)
		soldier.toggle_move_intent()
	// Their guns are part of the show: glued in, so nothing ever ends up on the floor.
	for(var/obj/item/held in soldier.held_items)
		ADD_TRAIT(held, TRAIT_NODROP, FNF_BATTLE_TRAIT)
	soldiers += soldier
	return soldier

/// Bang: the one on the speaker turns and fires, and down he goes.
/datum/fnf_stage/proc/shoot_soldier(mob/living/carbon/human/soldier, from_left)
	if(QDELETED(soldier) || !girlfriend || QDELETED(girlfriend))
		return
	GLOB.move_manager.stop_looping(soldier)
	var/facing = from_left ? WEST : EAST
	girlfriend.setDir(facing)
	girlfriend.fnf_act("aim_both", RIG_L_ARM, facing, null, 1)
	girlfriend_busy_until = world.time + 3
	var/turf/shooter_turf = get_turf(girlfriend)
	var/turf/target_turf = get_turf(soldier)
	// From up on the speakers, squatting.
	var/lift = seat?.rider == girlfriend ? seat.raised - 6 : 0
	if(shooter_turf && target_turf)
		tracer(shooter_turf, 16 + (from_left ? -10 : 10), 26 + lift, (target_turf.x - shooter_turf.x) * world.icon_size + 16, (target_turf.y - shooter_turf.y) * world.icon_size + 22)
	soldier.limb_rig?.step_delay_override = null
	// Knocked flying: a ragdoll, kicked away from the shooter, falling however physics has it.
	// Without the physics library, a flinch and a fall.
	if(soldier.set_limb_physics(TRUE))
		var/datum/limb_physics/ragdoll = soldier.limb_rig.physics
		var/away = from_left ? -1 : 1
		ragdoll.push(RIG_CHEST, away * 45, 12)
		ragdoll.push(RIG_HEAD, away * 10, 4)
		ragdoll.twist(RIG_CHEST, away * -2)
	else
		soldier.fnf_act("hit_high", RIG_R_ARM, soldier.dir, null, 2)
		ADD_TRAIT(soldier, TRAIT_FLOORED, FNF_BATTLE_TRAIT)
	var/obj/effect/abstract/fnf_hud/blood = new(target_turf)
	blood.icon = 'icons/effects/blood.dmi'
	blood.icon_state = "floor[rand(1, 7)]"
	blood.color = "#a10808"
	blood.plane = GAME_PLANE
	blood.layer = LOW_OBJ_LAYER
	blood.alpha = 0
	animate(blood, alpha = 230, time = 5)
	animate(alpha = 0, time = 10, delay = 8)
	QDEL_IN(blood, 25)
	addtimer(CALLBACK(src, PROC_REF(bench_soldier), soldier), 8, TIMER_DELETE_ME)

/// A shot tankman vanishes, quickly, and goes back on the bench for the next run.
/datum/fnf_stage/proc/bench_soldier(mob/living/carbon/human/soldier)
	if(QDELETED(soldier))
		return
	animate(soldier, alpha = 0, time = 2)
	addtimer(CALLBACK(src, PROC_REF(soldier_benched), soldier), 2, TIMER_DELETE_ME)

/datum/fnf_stage/proc/soldier_benched(mob/living/carbon/human/soldier)
	if(QDELETED(soldier))
		return
	soldier.set_limb_physics(FALSE)
	REMOVE_TRAIT(soldier, TRAIT_FLOORED, FNF_BATTLE_TRAIT)
	soldier.moveToNullspace()
	idle_soldiers += soldier

/// Puts up the lyrics as the song reaches them.
/datum/fnf_stage/proc/tick(now)
	send_soldiers(now)
	if(!lyric_text)
		return
	var/list/lyrics = battle.song.lyrics
	if(lyric_ends >= 0 && now >= lyric_ends)
		lyric_text.maptext = null
		lyric_ends = -1
	while(next_lyric <= length(lyrics))
		var/list/line = lyrics[next_lyric]
		if(line[1] > now)
			break
		next_lyric++
		if(line[2] <= now)
			continue
		lyric_ends = line[2]
		lyric_text.maptext = MAPTEXT("<span style='text-align:center;font-size:8pt;color:#ffffff;-dm-text-outline:1px #000000'><i>[html_encode(line[3])]</i></span>")

/**
 * A chart's PlayAnimation event: someone on stage does something.
 *
 * * target - who: "bf" or "boyfriend" (the right), "dad" (the left), "gf" or "girlfriend"
 * * anim - what, as Funkin' names the animation
 */
/datum/fnf_stage/proc/play_animation(target, anim)
	var/datum/fnf_side/side
	switch(target)
		if("bf", "boyfriend")
			side = battle.right
		if("dad", "opponent")
			side = battle.left
		if("gf", "girlfriend")
			// Corruption+'s Purification has her dodging Carol's attacks.
			if(anim == "dodge" && girlfriend && !QDELETED(girlfriend))
				girlfriend_busy_until = world.time + 5
				girlfriend.fnf_act("dodge_high", RIG_R_ARM, SOUTH, null, 3)
			else
				cheer()
			return
	if(!side)
		return
	switch(anim)
		if("hey", "cheer")
			side.hey()
			// Boyfriend shouts "hey!"; Pico says "yeah!".
			cheer()
		if("ugh", "augh")
			side.act("ugh", 4)
		if("laugh")
			side.act("taunt", 5)
		if("beat it")
			side.act("taunt", 4)
		if("hehPrettyGood")
			side.hey()
		if("burpSmile")
			side.act("taunt", 3)
		if("redheadsAnim")
			// "Ugh, redheads..."
			side.act("taunt", 5)
		if("knifeToss")
			knife_toss()
		// Corruption+: corrupted Pico screaming, fighting it; Kapi's meow; being lost in a flashback.
		if("scream")
			side.scream()
		if("meow")
			side.act("meow", 6)
		if("confused1", "confused2")
			side.act("confused", 6)
		if("taunt", "cocky")
			side.act("taunt", 5)
		if("hey!")
			side.hey()
		// Carol's harp, which nobody here has.
		if("strings")
			return
		else
			side.hey()

/// Stress (Pico Mix): Nene, clinging to Pico, has heard enough about redheads, and throws a knife
/// at Tankman.
/datum/fnf_stage/proc/knife_toss()
	var/datum/fnf_side/tankman = battle.left
	var/mob/living/thrower = carried || battle.right?.singer
	if(!thrower || !tankman?.singer)
		return
	thrower.fnf_act("punch_high", RIG_R_ARM, battle.right.facing, null, 3)
	var/obj/effect/abstract/fnf_hud/knife = new(get_turf(thrower))
	knife.icon = 'icons/obj/service/kitchen.dmi'
	knife.icon_state = "knife"
	knife.pixel_w = thrower.pixel_w
	knife.pixel_z = 14
	animate(knife, pixel_w = -gap_px, pixel_z = 10, transform = turn(matrix(), -1080), time = 3, easing = LINEAR_EASING)
	QDEL_IN(knife, 3)
	addtimer(CALLBACK(src, PROC_REF(knife_lands)), 3, TIMER_DELETE_ME)

/datum/fnf_stage/proc/knife_lands()
	var/datum/fnf_side/tankman = battle?.left
	if(!tankman?.singer)
		return
	playsound(tankman.singer, 'sound/items/weapons/bladeslice.ogg', 60, TRUE)
	tankman.act("hit_high", 5)
	stick_knife_in_head(tankman.singer)

/**
 * Leaves the knife stuck in someone's head for the rest of the song: on the head itself if they're
 * rigged, so it nods with it. The in-hand knife sprite, handle out toward whoever threw it.
 */
/datum/fnf_stage/proc/stick_knife_in_head(mob/living/victim)
	if(knifed)
		return
	var/mob/living/carbon/rigged = victim
	var/datum/limb_rig/rig = istype(rigged) ? rigged.limb_rig : null
	var/atom/holder = rig?.parts[RIG_HEAD] || victim
	// Thrown from the right, so the blade points left into the head and the handle sticks out right.
	head_knife = image('icons/mob/inhands/equipment/kitchen_righthand.dmi', "knife", dir = WEST)
	// That sprite's blade is centred at (9.5, 13.5); the head's middle is about (19, 31), or (19, 25)
	// on a human-sized head.
	var/head_y = istype(rig, /datum/limb_rig/sprites) ? 31 : 25
	head_knife.pixel_w = 19 - 9.5
	head_knife.pixel_z = head_y - 13.5
	head_knife.appearance_flags = RESET_COLOR|PIXEL_SCALE
	holder.add_overlay(head_knife)
	knifed = holder

/// The girlfriend throws her arms up: "Hey!"
/datum/fnf_stage/proc/cheer()
	if(!girlfriend || QDELETED(girlfriend))
		return
	girlfriend.fnf_hey(RIG_R_ARM, SOUTH, null)

/// The singer on the other side from this one.
/datum/fnf_stage/proc/rival_of(datum/fnf_side/side)
	return side == battle.left ? battle.right : battle.left

/**
 * A note was hit. Returns TRUE if it was a move the stage acted out, so the singer doesn't also
 * sing it.
 */
/datum/fnf_stage/proc/note_hit(datum/fnf_side/side, datum/fnf_note/note)
	var/kind = note.kind
	if(!kind)
		return FALSE
	switch(kind)
		if("noanim")
			return TRUE
		if("gf")
			// Whoever's in her place sings it (Purification's corrupted Boyfriend, taking over), and
			// whoever usually would just hangs there, twitching.
			if(!girlfriend || QDELETED(girlfriend))
				return FALSE
			girlfriend_busy_until = world.time + max(note.length / 100, 2) + 1.5
			girlfriend.setDir(girlfriend_facing)
			girlfriend.fnf_sing(note.lane, max(note.length / 100, 2), girlfriend_facing == SOUTH ? RIG_R_ARM : girlfriend.fnf_mic_arm(girlfriend_facing), girlfriend_facing, girlfriend.fnf_look)
			return TRUE
		if("ugh")
			side.act("ugh", 3)
			return TRUE
		if("hehPrettyGood")
			side.hey()
			return TRUE
	if(findtext(kind, "weekend-1-") != 1)
		return FALSE
	var/move = copytext(kind, 11)
	if(weekend_cans(side, move, TRUE))
		return TRUE
	return blazin(side, move, TRUE)

/// A note was missed. Returns TRUE if the stage showed what that cost, instead of the usual flinch.
/datum/fnf_stage/proc/note_missed(datum/fnf_side/side, datum/fnf_note/note)
	if(findtext(note.kind, "weekend-1-") != 1)
		return FALSE
	var/move = copytext(note.kind, 11)
	if(weekend_cans(side, move, FALSE))
		return TRUE
	return blazin(side, move, FALSE)

/**
 * 2hot: Darnell lights a can, kicks it up (and knees it higher), Pico racks his gun and shoots it
 * out of the air. Miss the shot and the can comes down on Pico's head.
 */
/datum/fnf_stage/proc/weekend_cans(datum/fnf_side/side, move, hit)
	var/static/list/can_moves = list("lightcan", "kickcan", "kneecan", "cockgun", "firegun")
	if(!(move in can_moves))
		return FALSE
	var/datum/fnf_side/darnell = battle.left
	var/datum/fnf_side/pico = battle.right
	if(!darnell.singer || !pico.singer)
		return TRUE
	// Where the can hangs to be shot: in the air between them, right where Pico's gun points.
	var/hover_x = gap_px * 0.55
	var/hover_y = 31 + max(gap_px * 0.45 - 9, 8) * 0.7
	switch(move)
		if("lightcan")
			darnell.act("cock", 3)
			QDEL_NULL(can)
			can = new(get_turf(darnell.singer))
			can.icon = 'icons/obj/art/crayons.dmi'
			can.icon_state = "spraycan"
			can.pixel_w = 8
			can.pixel_z = 6
			playsound(darnell.singer, 'sound/items/lighter/zippo_on.ogg', 50, TRUE)
		if("kickcan")
			darnell.act("kick", 2)
			if(can)
				playsound(darnell.singer, 'sound/items/weapons/genhit1.ogg', 40, TRUE)
				// Up in an arc over toward Pico, and hanging there.
				animate(can, pixel_w = hover_x - 16, pixel_z = hover_y + 10 - 16, transform = turn(matrix(), 360), time = 4, easing = SINE_EASING|EASE_OUT)
				animate(pixel_z = hover_y - 16, time = 6, easing = SINE_EASING)
		if("kneecan")
			darnell.act("kick", 2)
			if(can)
				playsound(darnell.singer, 'sound/items/weapons/genhit2.ogg', 40, TRUE)
				animate(can, pixel_w = hover_x - 16, pixel_z = hover_y + 14 - 16, transform = turn(matrix(), 180), time = 3, easing = SINE_EASING|EASE_OUT)
				animate(pixel_z = hover_y - 16, time = 5, easing = SINE_EASING)
		if("cockgun")
			pico.act("cock", 3)
			playsound(pico.singer, 'voidcrew/modules/fnf/sound/gun_cock.ogg', 50, TRUE)
		if("firegun")
			if(hit)
				pico.act("shoot", 2)
				playsound(pico.singer, "voidcrew/modules/fnf/sound/shot[rand(1, 4)].ogg", 60, TRUE)
				if(can)
					tracer(get_turf(darnell.singer), gap_px - 9, 31, can.pixel_w + 16, can.pixel_z + 16)
					var/obj/effect/temp_visual/explosion/fast/pop = new(can.loc)
					// It's already moved 32 px down and left to centre its 96 px sprite on a tile.
					pop.pixel_w = can.pixel_w
					pop.pixel_z = can.pixel_z
					pop.transform = matrix() * 0.35
					playsound(can, 'sound/effects/pop_expl.ogg', 40, TRUE)
					QDEL_NULL(can)
			else
				// Unshot, the can comes down and goes off in Pico's face.
				if(can)
					var/face_x = gap_px - 3
					animate(can, pixel_w = face_x - 16, pixel_z = 31 - 16, transform = turn(matrix(), 540), time = 2, easing = QUAD_EASING|EASE_IN)
					addtimer(CALLBACK(src, PROC_REF(can_in_face), can, face_x), 2, TIMER_DELETE_ME)
					can = null
	return TRUE

/// The can Pico didn't shoot blows up in his face: a big chunk of health, and charred for a moment.
/datum/fnf_stage/proc/can_in_face(obj/effect/abstract/fnf_hud/missed_can, face_x)
	var/turf/where = missed_can.loc
	qdel(missed_can)
	var/datum/fnf_side/pico = battle?.right
	if(!pico?.singer || !where)
		return
	var/obj/effect/temp_visual/explosion/fast/bang = new(where)
	bang.pixel_w = face_x - 16
	bang.pixel_z = 31 - 16
	bang.transform = matrix() * 0.55
	playsound(pico.singer, 'sound/effects/pop_expl.ogg', 70, TRUE)
	shake_camera(pico.singer, 3, 1)
	pico.singer.fnf_flash("#2a3470", 8)
	pico.act("hit_high", 4)
	battle.adjust_health(-32, pico)

/// A bullet's streak, from one point to another (pixels from the bottom left of a turf).
/datum/fnf_stage/proc/tracer(turf/from_turf, from_x, from_y, to_x, to_y)
	var/delta_x = to_x - from_x
	var/delta_y = to_y - from_y
	var/length = sqrt(delta_x ** 2 + delta_y ** 2)
	var/obj/effect/abstract/fnf_hud/streak = new(from_turf)
	streak.icon_state = "bar"
	streak.color = "#fff3a0"
	streak.pixel_w = (from_x + to_x) / 2 - 16
	streak.pixel_z = (from_y + to_y) / 2 - 16
	var/matrix/line = matrix(length / 32, 0, 0, 0, 1 / 32, 0)
	line.Turn(-arctan(delta_x, delta_y))
	streak.transform = line
	animate(streak, alpha = 0, time = 2)
	QDEL_IN(streak, 3)

/**
 * Blazin': every note is a move in the fight between Pico (right) and Darnell (left), named for
 * what Pico does or has done to him. Hit it and it goes Pico's way; miss it and it doesn't: a
 * whiffed punch, or a punch that should have been blocked landing.
 */
/datum/fnf_stage/proc/blazin(datum/fnf_side/side, move, hit)
	var/datum/fnf_side/darnell = battle.left
	var/datum/fnf_side/pico = battle.right
	var/static/list/punches = list(
		"punchhigh" = "high", "punchlow" = "low", "punchhighspin" = "high", "punchlowspin" = "low",
	)
	var/static/list/blocked_punches = list("punchhighblocked" = "high", "punchlowblocked" = "low", "punchlowdodged" = "low")
	var/static/list/guards = list("blockhigh" = "high", "blocklow" = "low", "blockspin" = "high", "dodgehigh" = "high", "dodgelow" = "low")
	var/static/list/hits = list("hithigh" = "high", "hitlow" = "low")
	if(!darnell.singer || !pico.singer)
		return FALSE
	if(punches[move])
		var/height = punches[move]
		pico.act("punch_[height]", 2)
		if(hit)
			darnell.act("hit_[height]", 3)
			punch_sound(darnell)
		else
			darnell.act("dodge_[height]", 3)
		return TRUE
	if(blocked_punches[move])
		var/height = blocked_punches[move]
		pico.act("punch_[height]", 2)
		if(findtext(move, "dodged"))
			darnell.act("dodge_[height]", 3)
		else
			darnell.act("block", 3)
			playsound(darnell.singer, 'sound/items/weapons/block_shield.ogg', 40, TRUE)
		return TRUE
	if(guards[move])
		var/height = guards[move]
		darnell.act("punch_[height]", 2)
		if(hit)
			if(findtext(move, "dodge"))
				pico.act("dodge_[height]", 3)
			else
				pico.act("block", 3)
				playsound(pico.singer, 'sound/items/weapons/block_shield.ogg', 40, TRUE)
		else
			pico.act("hit_[height]", 3)
			punch_sound(pico)
		return TRUE
	if(hits[move])
		// Scripted: Darnell gets one in whatever happens.
		var/height = hits[move]
		darnell.act("punch_[height]", 2)
		pico.act("hit_[height]", 3)
		punch_sound(pico)
		return TRUE
	switch(move)
		if("picouppercutprep")
			pico.act("prep", 4)
		if("picouppercut")
			pico.act("uppercut", 3)
			if(hit)
				darnell.act("uppercut_hit", 5)
				punch_sound(darnell, TRUE)
			else
				darnell.act("dodge_high", 3)
		if("darnelluppercutprep")
			darnell.act("prep", 4)
		if("darnelluppercut")
			darnell.act("uppercut", 3)
			if(hit)
				pico.act("dodge_high", 3)
			else
				pico.act("uppercut_hit", 5)
				punch_sound(pico, TRUE)
		if("fakeout")
			pico.act("punch_high", 1)
			darnell.act("block", 3)
		if("taunt")
			pico.act("taunt", 5)
		if("idle")
			return TRUE
		else
			return FALSE
	return TRUE

/datum/fnf_stage/proc/punch_sound(datum/fnf_side/struck, big = FALSE)
	if(struck.singer)
		playsound(struck.singer, "sound/items/weapons/punch[rand(1, 4)].ogg", big ? 70 : 50, TRUE)
		shake_camera(struck.singer, big ? 3 : 1, big ? 1 : 0.5)

#undef FNF_SOLDIER_RUN_MS
#undef FNF_MAX_SOLDIERS
