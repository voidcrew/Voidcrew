/// Where the tests put the song they make (see make_fnf_test_song()): no song ships with the game.
#define FNF_TEST_SONGS "data/unit_test_fnf/"

/**
 * Makes a song to test with, in Funkin's format, and adds its folder to the song list: an
 * Experiment against an Experiment, the two taking turns every 0.4 seconds for 26 seconds, every
 * eighth note held. Its audio is the countdown's. Returns its name; take_fnf_test_song() clears it up.
 */
/proc/make_fnf_test_song()
	var/folder = FNF_TEST_SONGS + "testsong/"
	fdel(FNF_TEST_SONGS)
	var/list/notes = list()
	for(var/index in 0 to 63)
		var/hold = index % 8 == 0 ? 300 : 0
		notes += list(list("t" = 1000 + index * 400, "d" = 4 + index % 4, "l" = hold))
		notes += list(list("t" = 1200 + index * 400, "d" = index % 4, "l" = hold))
	text2file(json_encode(list("version" = "2.0.0", "scrollSpeed" = list("normal" = 1.4), "events" = list(), "notes" = list("normal" = notes))), folder + "testsong-chart.json")
	text2file(json_encode(list(
		"songName" = "Test Song",
		"artist" = "the unit tests",
		"timeChanges" = list(list("t" = 0, "bpm" = 150)),
		"playData" = list(
			"difficulties" = list("normal"),
			"characters" = list("player" = "expie", "opponent" = "expie", "playerVocals" = list("player"), "opponentVocals" = list("opponent")),
		),
	)), folder + "testsong-metadata.json")
	for(var/audio in list("Inst.ogg", "Voices-player.ogg", "Voices-opponent.ogg"))
		fcopy('voidcrew/modules/fnf/sound/count1.ogg', folder + audio)
	GLOB.fnf_song_dirs |= FNF_TEST_SONGS
	return "Test Song"

/proc/take_fnf_test_song()
	GLOB.fnf_song_dirs -= FNF_TEST_SONGS
	fdel(FNF_TEST_SONGS)
	get_fnf_songs(refresh = TRUE)

/// A song loads, with both singers' vocals and its long notes.
/datum/unit_test/fnf_song

/datum/unit_test/fnf_song/Run()
	var/name = make_fnf_test_song()
	var/list/songs = get_fnf_songs(refresh = TRUE)
	var/datum/fnf_song/song = songs[name]
	TEST_ASSERT_NOTNULL(song, "The test song did not load.")
	TEST_ASSERT_NOTNULL(song.player_voice_file, "The test song has no player vocals.")
	TEST_ASSERT_NOTNULL(song.opponent_voice_file, "The test song has no opponent vocals.")
	var/list/chart = song.load_chart("normal")
	TEST_ASSERT_EQUAL(length(chart["player"]), 64, "The test chart's player notes didn't all load.")
	TEST_ASSERT_EQUAL(length(chart["opponent"]), 64, "The test chart's opponent notes didn't all load.")
	var/holds = 0
	for(var/list/note as anything in chart["player"])
		if(note[3] > 0)
			holds++
	TEST_ASSERT_EQUAL(holds, 8, "The test chart's long notes didn't load.")

/datum/unit_test/fnf_song/Destroy()
	take_fnf_test_song()
	return ..()

/// A lone challenger gets an Experiment to sing against, the game plays both sides when nobody's
/// at the keys, and the summoned singer goes when the battle does.
/datum/unit_test/fnf_battle

/datum/unit_test/fnf_battle/Run()
	var/name = make_fnf_test_song()
	var/list/songs = get_fnf_songs(refresh = TRUE)
	var/datum/fnf_song/song = songs[name]
	TEST_ASSERT_NOTNULL(song, "The test song did not load.")
	var/mob/living/carbon/human/consistent/challenger = allocate(/mob/living/carbon/human/consistent)
	var/datum/fnf_battle/battle = new(song, "normal")
	battle.start(challenger, null)
	var/mob/living/carbon/human/npc = battle.npc
	TEST_ASSERT_NOTNULL(npc, "No opponent was summoned for a lone challenger.")
	TEST_ASSERT(is_species(npc, /datum/species/experiment), "The summoned opponent is not an Experiment.")
	TEST_ASSERT(battle.left.is_cpu && battle.right.is_cpu, "Singers without players are not played by the game.")

	// Twenty-five seconds in, past both singers' first verses: everything due so far gets sung.
	battle.start_time = world.time - 250
	battle.state = 2
	battle.tick()
	TEST_ASSERT(battle.right.score > 0, "The challenger's side sang nothing.")
	TEST_ASSERT(battle.left.score > 0, "The opponent's side sang nothing.")
	TEST_ASSERT_EQUAL(battle.right.misses, 0, "The game missed notes it was playing itself.")
	TEST_ASSERT_EQUAL(battle.health, 50, "The game playing itself moved the health bar.")

	qdel(battle)
	TEST_ASSERT(QDELETED(npc), "The summoned opponent stayed after the battle.")

/datum/unit_test/fnf_battle/Destroy()
	take_fnf_test_song()
	return ..()

/// Songs are picked by week, in Funkin's order, and lyrics are read from SubRip timings.
/datum/unit_test/fnf_weeks

/datum/unit_test/fnf_weeks/Run()
	TEST_ASSERT_EQUAL(fnf_week_label("week1"), "Week 1", "week1 is not labelled Week 1.")
	TEST_ASSERT_EQUAL(fnf_week_label("weekend1"), "Weekend 1", "weekend1 is not labelled Weekend 1.")
	TEST_ASSERT_EQUAL(fnf_week_label("tutorial"), "Tutorial", "tutorial is not labelled Tutorial.")
	var/list/weeks = list("weekend1", "week7", "sserafim", "week1", "tutorial")
	sortTim(weeks, GLOBAL_PROC_REF(cmp_fnf_week))
	TEST_ASSERT_EQUAL(jointext(weeks, ","), "tutorial,week1,week7,weekend1,sserafim", "Weeks are not in Funkin's order.")
	TEST_ASSERT_EQUAL(fnf_srt_time("00:01:02,500"), 62500, "A SubRip time was read wrong.")
	TEST_ASSERT_NULL(fnf_srt_time("not a time"), "A broken SubRip time was read as a time.")

/// Every head that pulls faces has every face, and the head's own eye cover; a singer's face goes
/// on with a note, back to idle after, and off when the battle's over.
/datum/unit_test/fnf_faces

/datum/unit_test/fnf_faces/Run()
	var/list/states = icon_states('voidcrew/modules/fnf/icons/fnf_faces.dmi')
	var/list/expressions = list("idle", "left", "down", "up", "right", "miss", "hey", "dead")
	for(var/face_set in list("human", "human_white", "human_demon", "lizard", "moth", "ethereal", "skeleton"))
		for(var/expression in expressions)
			TEST_ASSERT("[face_set]_[expression]" in states, "The [face_set] faces have no [expression] face.")
	for(var/face_set in list("human", "lizard", "moth", "ethereal", "skeleton"))
		TEST_ASSERT("[face_set]_cover" in states, "The [face_set] faces don't cover the head's own eyes.")
		TEST_ASSERT("[face_set]_windowcover" in states, "The [face_set] faces have no patch for a half-freed eye.")
		for(var/expression in expressions)
			TEST_ASSERT("[face_set]_window_[expression]" in states, "The [face_set] faces have no half-freed [expression] eye.")
			TEST_ASSERT("[face_set]_mouth_[expression]" in states, "The [face_set] faces have no [expression] mouth for covered eyes.")
	var/list/experiment_states = icon_states('voidcrew/modules/fnf/icons/fnf_faces_experiment.dmi')
	for(var/expression in expressions)
		TEST_ASSERT("experiment_[expression]" in experiment_states, "The Experiment has no [expression] face.")
	TEST_ASSERT_NULL(get_fnf_face_set("plasmaman"), "Plasmamen pull faces.")

	var/mob/living/carbon/human/consistent/singer = allocate(/mob/living/carbon/human/consistent)
	singer.update_limb_rig()
	var/datum/limb_rig/sprites/humanoid/rig = singer.limb_rig
	TEST_ASSERT(istype(rig), "A human has no humanoid rig to pull faces with.")
	singer.fnf_sing(2, 3, "r_arm", EAST, null)
	TEST_ASSERT_EQUAL(rig.fnf_face, "up", "Singing an up note didn't pull the up face.")
	TEST_ASSERT(rig.is_pulling_fnf_face(), "The up face isn't held for the note.")
	TEST_ASSERT_EQUAL(length(rig.fnf_face_images), 2, "The face isn't drawn over the head.")
	singer.fnf_rest()
	TEST_ASSERT_NULL(rig.fnf_face, "The face stayed on after the battle.")
	TEST_ASSERT_NULL(rig.fnf_face_images, "The face is still drawn after the battle.")

/// Corruption+'s cast all have looks, a body corrupts piece by piece and comes back clean, and a
/// song's character changes are read from its chart and its events file, in order, once each.
/datum/unit_test/fnf_corruption

/datum/unit_test/fnf_corruption/Run()
	for(var/character in GLOB.fnf_corruption_cast)
		var/list/cast = GLOB.fnf_corruption_cast[character]
		if(cast["look"])
			TEST_ASSERT(GLOB.fnf_opponents[cast["look"]], "Corruption+'s [character] has no look: [cast["look"]].")

	var/mob/living/carbon/human/consistent/singer = allocate(/mob/living/carbon/human/consistent)
	singer.update_limb_rig()
	singer.setDir(EAST)
	var/datum/limb_rig/rig = singer.limb_rig
	rig.set_corruption(0.1)
	// The far side goes first: facing east, the left arm's taken before the right.
	TEST_ASSERT(rig.get_corruption_of("l_arm", "l") > rig.get_corruption_of("r_arm", "l"), "Corruption didn't start on the far side.")
	TEST_ASSERT(!rig.is_face_corrupted(), "The face was taken with barely any corruption.")
	rig.set_corruption(1, "red")
	TEST_ASSERT(length(rig.corruption_images), "Corruption drew nothing on the body.")
	TEST_ASSERT(rig.is_face_corrupted(), "Full corruption didn't take the face.")
	// The glowing face has a piece of its own, or the colour on the head would go over it too.
	var/atom/movable/face_holder = rig.get_fnf_face_holder()
	TEST_ASSERT(face_holder, "There's nothing for the face to be drawn on.")
	TEST_ASSERT_NULL(face_holder.color, "Corruption coloured the face along with the head.")
	TEST_ASSERT_EQUAL(length(fnf_tint_then_colour("#808080", list(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0))), 20, "A tint and a colour matrix don't make one matrix.")
	var/datum/limb_rig/sprites/sprite_rig = rig
	if(istype(sprite_rig))
		TEST_ASSERT(sprite_rig.sprite_saturation < 1, "Corruption didn't drain the body's own sprites.")
	TEST_ASSERT("human_laugh" in icon_states('voidcrew/modules/fnf/icons/fnf_faces.dmi'), "There's no manic grin for Carol's face.")
	// The cast's traced moves: corrupted Pico's, turned round for whichever way he faces.
	TEST_ASSERT(length(fnf_traced_keyframes("cpico", "idle", WEST)), "Corrupted Pico's traced idle is missing.")
	var/list/left_west = fnf_traced_keyframes("cpico", "singLEFT", WEST)
	var/list/right_east = fnf_traced_keyframes("cpico", "singRIGHT", EAST)
	TEST_ASSERT(length(left_west) && length(left_west) == length(right_east), "A traced move isn't swapped for a singer facing the other way from the sprite.")
	TEST_ASSERT_NULL(fnf_traced_keyframes("bf", "idle", WEST), "Someone nobody traced got a traced move.")
	// A long note stutters on a move's first two frames before playing it through; a short one just plays it.
	var/list/move = list(list(list("a" = 1), 0.4), list(list("b" = 1), 0.4), list(list("c" = 1), 0.4))
	TEST_ASSERT_EQUAL(length(fnf_traced_hold(move, 1, list())), 4, "A short note's traced move didn't just play through.")
	var/list/held = fnf_traced_hold(move, 3, list())
	TEST_ASSERT(length(held) > 4 && held[1][1] == move[1][1] && held[2][1] == move[2][1] && held[3][1] == move[1][1], "A long note's traced move doesn't repeat its first frames.")
	var/list/frame_states = icon_states('voidcrew/modules/fnf/icons/fnf_healthbar_tainted.dmi')
	TEST_ASSERT(("hole" in frame_states) && ("block" in frame_states), "The tainted health bar has no opening for its colours to fill.")
	var/list/prop_states = icon_states('voidcrew/modules/fnf/icons/fnf_props.dmi')
	var/list/seat_states = icon_states('voidcrew/modules/fnf/icons/fnf_speakers.dmi')
	for(var/character in GLOB.fnf_corruption_cast)
		var/list/cast = GLOB.fnf_corruption_cast[character]
		TEST_ASSERT(cast["bar"], "Corruption+'s [character] has no colour on the health bar.")
		TEST_ASSERT(!cast["seat"] || (cast["seat"] in seat_states), "Corruption+'s [character] sits on something that isn't drawn: [cast["seat"]].")
		TEST_ASSERT(!cast["prop"] || (cast["prop"] in prop_states), "Corruption+'s [character] has a prop that isn't drawn: [cast["prop"]].")
	TEST_ASSERT(("speakers" in seat_states) && ("abot" in seat_states), "Girlfriend's speakers or Nene's A-Bot aren't drawn.")
	for(var/lane in list("left", "down", "up", "right"))
		TEST_ASSERT("dance_pad_lit_[lane]" in prop_states, "Kapi's dance pad has no [lane] panel to light up.")
	var/list/coats = icon_states('voidcrew/modules/fnf/icons/corruption_coats.dmi')
	for(var/coat in list("coat_humanoid_chest_8", "coat_humanoid_chest_f_1", "coat_experiment_tail_4", "coat_milkie_head_8"))
		TEST_ASSERT(coat in coats, "Corruption's coat isn't baked for [coat].")
	TEST_ASSERT_EQUAL(length(fnf_blend_colour_matrices(color_matrix_saturation(0.5), list(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0), 0.5)), 20, "Colour matrices don't blend.")
	// Fighting it off frees the head first, while the far side stays taken.
	rig.set_corruption(0.7)
	TEST_ASSERT(rig.get_corruption_of("head", "l") < rig.get_corruption_of("l_arm", "l"), "Fighting corruption off didn't free the head before the far side.")
	TEST_ASSERT_EQUAL(rig.get_corruption_of("l_arm", "l"), 1, "Fighting corruption off freed the far arm early.")
	TEST_ASSERT(rig.is_face_half_freed(), "Fighting corruption off didn't give half the face back.")
	rig.set_corruption(0.5)
	TEST_ASSERT(!rig.is_face_corrupted(), "Fighting corruption well off didn't give the whole face back.")
	rig.set_corruption(0)
	TEST_ASSERT_NULL(rig.corruption_images, "Corruption stayed drawn on the body after it was cleared.")
	if(istype(sprite_rig))
		TEST_ASSERT_EQUAL(sprite_rig.sprite_saturation, 1, "The body's sprites stayed drained after corruption was cleared.")

	var/datum/fnf_song/song = new("data/fnf/tests/", "none")
	song.path = "data/fnf/tests/"
	var/list/changes = song.read_character_changes(list("events" = list(
		list(2000, list(list("Change Character", "1", "kapi1"))),
		list(1000, list(list("Change Character", "dad", "kapi"), list("Change Character", "2", "speakers"))),
		list(2000, list(list("Change Character", "1", "kapi1"))),
		list(3000, list(list("Play Animation", "meow", "Dad"))),
	)))
	TEST_ASSERT_EQUAL(length(changes), 3, "A chart's character changes weren't read once each.")
	var/list/acted = song.read_overlay_events(list("events" = list(
		list(95620, list(list("Play Animation", "scream", "BF"), list("Screen Shake", "0.3, 0.005", "0.3, 0.005"))),
	)))
	TEST_ASSERT_EQUAL(length(acted), 2, "A chart's animation and shake events weren't read.")
	var/list/scream = acted[1]
	TEST_ASSERT(scream[2] == "anim" && scream[3] == "scream" && scream[4] == "bf", "A chart's scream wasn't read as the player's.")
	var/list/screens = song.read_overlay_events(list("events" = list(
		list(1000, list(list("Lightr", "0.5", ""), list("badapplelol", "a", "1"), list("flashBom", "1", "2"))),
	)))
	TEST_ASSERT_EQUAL(length(screens), 2, "A chart's flash and silhouette events weren't read, or its glow was.")
	var/list/flash = screens[1]
	TEST_ASSERT(flash[2] == "light" && flash[3] == "#960030", "A chart's crimson flash wasn't read as one.")
	var/list/overlay_states = icon_states('voidcrew/modules/fnf/icons/fnf_corruption_overlays.dmi')
	TEST_ASSERT(("scary_top" in overlay_states) && ("scary_bottom" in overlay_states), "The overlays have no edges to fill a taller view with.")
	var/list/first = changes[1]
	TEST_ASSERT(first[1] == 1000 && first[2] == "opponent" && first[3] == "kapi", "A chart's character changes are out of order, or their roles are wrong.")

#undef FNF_TEST_SONGS
