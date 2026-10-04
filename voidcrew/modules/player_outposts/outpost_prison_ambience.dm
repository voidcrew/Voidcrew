/**
 * # Prison ambience: the yard notices you, readable moods, a riot you hear coming
 *
 * Owner: XB (extras-plan.md 4.5 and 4.7). Heads turn when a member walks into the cell block;
 * examining a prisoner describes their mood in words (with every package's extra lines from
 * examine_extra_lines()); sour prisoners sulk and content ones hum; a restless yard hushes, a
 * brewing riot slams the tables and chants, and the riot starts with a roar.
 *
 * All of it is cheap and short range: one pass over the level's players a second, a few view()
 * checks at most once a minute, examine only when someone looks, and at most two quiet slams a
 * second while a riot brews. Nothing here moves pay; it shows what the mood and the tension
 * already are. Numbers in voidcrew/_DEFINES/outpost_prison_security.dm; the prisoners' lines in
 * strings/outpost_prison_security.json ("lines" for speech, "examine" for the mood descriptions).
 */

/// Offset source for a prisoner slumped against a wall, sulking
#define PRISONER_SULK_OFFSET "outpost_prisoner_sulk"
// What an activity's tick() wants next, as in outpost_prison_routine.dm (which undefines its own)
#define ACTIVITY_DONE 1

/// Placeholders an examine line may use, for the prisoner's pronouns and the verb ending that goes with them
GLOBAL_LIST_INIT(outpost_prisoner_examine_placeholders, list("{They}", "{they}", "{Their}", "{their}", "{them}", "{s}", "{es}"))

// ===== THE PRISONER =====

/mob/living/basic/outpost_prisoner
	/// Picks their examine line within a mood band, so looking twice reads the same
	var/ambience_examine_seed = 0
	/// Running after they turned to look at staff coming in, after humming, and after a whisper in a huddle
	COOLDOWN_DECLARE(ambience_notice_cooldown)
	COOLDOWN_DECLARE(ambience_hum_cooldown)
	COOLDOWN_DECLARE(ambience_huddle_cooldown)

/// Hooks up the prisoner's side of the ambience; called from setup_extras(). Nothing needs hooking: the prison drives it from its tick, and examine is the override below.
/mob/living/basic/outpost_prisoner/proc/setup_ambience()
	return

/**
 * Their mood in words, by band and personality, and one line on how they are kept when something
 * shows (hurt, a dirty jumpsuit, shut in, due out), then every package's own lines. Never a number.
 */
/mob/living/basic/outpost_prisoner/examine(mob/user)
	. = ..()
	if(stat == DEAD || phase != PRISONER_PRESENT)
		return
	var/mood_line = mood_examine_line()
	if(mood_line)
		. += mood < PRISONER_THREAT_MOOD ? span_warning(mood_line) : span_notice(mood_line)
	var/state_line = state_examine_line()
	if(state_line)
		. += span_notice(state_line)
	if(prison)
		for(var/line in prison.examine_extra_lines(src, user))
			. += span_notice(line)

/// A closer look: what they are in for, their cell, roughly how long they have left, and their birthday until the yard has had the cake
/mob/living/basic/outpost_prisoner/examine_more(mob/user)
	. = ..()
	if(stat == DEAD || !prison)
		return
	if(crime)
		. += span_notice("In for [crime].")
	if(cell)
		. += span_notice("Cell [cell.number].")
	if(phase == PRISONER_PRESENT && sentence_left > 0)
		. += span_notice("[capitalize(sentence_examine_text())] left on [p_their()] sentence.")
	// outpost_prison_life.dm
	if(has_birthday && !party_done)
		. += span_notice("It's [p_their()] birthday today.")

/// "a few minutes" or "about 25 minutes": their sentence left, rounded to OUTPOST_PRISONER_EXAMINE_ROUND_MINUTES
/mob/living/basic/outpost_prisoner/proc/sentence_examine_text()
	var/minutes = sentence_left / 60
	if(minutes < OUTPOST_PRISONER_EXAMINE_ROUND_MINUTES)
		return "a few minutes"
	return "about [round(minutes, OUTPOST_PRISONER_EXAMINE_ROUND_MINUTES)] minutes"

/// The "examine" key for their mood: the bands match the angry, threat, climb and tidy lines
/mob/living/basic/outpost_prisoner/proc/mood_examine_band()
	if(mood < PRISONER_THREAT_ANGRY_MOOD)
		return "mood_0"
	if(mood < PRISONER_THREAT_MOOD)
		return "mood_20"
	if(mood < PRISONER_CLIMB_MOOD)
		return "mood_35"
	if(mood < PRISONER_TIDY_MOOD)
		return "mood_50"
	return "mood_75"

/// A line on their mood, filled in, or null. Their own personality's lines come up more often than the shared ones.
/mob/living/basic/outpost_prisoner/proc/mood_examine_line()
	var/list/bands = outpost_prisoner_extra_dialogue("outpost_prison_security.json", "examine")
	var/list/band = bands[mood_examine_band()]
	if(!islist(band))
		return null
	if(!ambience_examine_seed)
		ambience_examine_seed = rand(1, 997)
	var/list/own = band[personality]
	var/list/shared = band["any"]
	var/list/pool = (length(own) && (ambience_examine_seed % 5) < 3) ? own : shared
	if(!length(pool))
		pool = length(own) ? own : shared
	if(!length(pool))
		return null
	return fill_examine_line(pool[(ambience_examine_seed % length(pool)) + 1])

/// Fills an examine line's pronouns ({They}, {their}, ...) and verb endings ({s}, {es}) for them
/mob/living/basic/outpost_prisoner/proc/fill_examine_line(line)
	if(!istext(line))
		return null
	line = replacetextEx(line, "{They}", p_They())
	line = replacetextEx(line, "{they}", p_they())
	line = replacetextEx(line, "{Their}", p_Their())
	line = replacetextEx(line, "{their}", p_their())
	line = replacetextEx(line, "{them}", p_them())
	line = replacetextEx(line, "{es}", p_es())
	line = replacetextEx(line, "{s}", p_s())
	return line

/// One line on how they are kept, the most pressing first, or null when nothing shows
/mob/living/basic/outpost_prisoner/proc/state_examine_line()
	var/health_percent = health_factor()
	if(health_percent < PRISONER_BLEED_BELOW)
		return "[p_They()] look[p_s()] badly hurt."
	if(health_percent < PRISONER_INJURED_BELOW)
		return "[p_They()] look[p_s()] a bit banged up."
	if(uniform_grime >= PRISONER_GRIME_FILTHY)
		return "[p_Their()] jumpsuit is filthy."
	if(uniform_grime >= PRISONER_GRIME_DIRTY)
		return "[p_Their()] jumpsuit could do with a wash."
	if(is_confined())
		return "[p_They()] [p_are()] shut in [p_their()] cell."
	if(sentence_left > 0 && sentence_left < OUTPOST_PRISONER_EXAMINE_DUE_OUT)
		return "[p_They()] [p_are()] due out any minute."
	return null

// ===== SULKING =====

/**
 * Sour and fed up: off on their own against a wall, in the yard or their own cell, slumped and
 * facing it. Never with another prisoner within OUTPOST_PRISONER_SULK_ALONE_RANGE tiles. Not a
 * mood activity, and nothing to anyone at OUTPOST_PRISONER_SULK_MOOD or better.
 */
/datum/prisoner_activity/sulk
	name = "sulking"
	leisure = TRUE
	weight = OUTPOST_PRISONER_SULK_WEIGHT
	personality_weights = list("grumpy" = 1.5, "quiet" = 1.5)
	min_duration = 20 SECONDS
	max_duration = 45 SECONDS
	/// The wall they face
	var/turf/wall
	/// Whether they have stared at it where others can see yet
	var/stared = FALSE

/datum/prisoner_activity/sulk/Destroy()
	wall = null
	return ..()

/datum/prisoner_activity/sulk/get_weight()
	if(prisoner.mood >= OUTPOST_PRISONER_SULK_MOOD)
		return 0
	return ..()

/datum/prisoner_activity/sulk/setup()
	var/datum/outpost_prison/prison = prisoner.prison
	if(!prison || !prisoner.walkable)
		return FALSE
	var/list/options = list()
	for(var/turf/tile as anything in prisoner.walkable)
		if((tile != prisoner.loc && prisoner.tile_taken(tile)) || !prisoner.may_loiter(tile))
			continue
		var/turf/beside_wall = sulk_wall_beside(tile)
		if(!beside_wall || sulk_company_near(tile))
			continue
		options[tile] = beside_wall
	if(!length(options))
		return FALSE
	spot = pick(options)
	wall = options[spot]
	return TRUE

/// A wall beside `tile`, or null
/datum/prisoner_activity/sulk/proc/sulk_wall_beside(turf/tile)
	for(var/direction in GLOB.cardinals)
		var/turf/next = get_step(tile, direction)
		if(isclosedturf(next))
			return next
	return null

/// Whether another prisoner is too close to `tile` to sulk there
/datum/prisoner_activity/sulk/proc/sulk_company_near(turf/tile)
	for(var/mob/living/basic/outpost_prisoner/other in prisoner.prison.prisoners)
		if(other != prisoner && get_dist(other, tile) <= OUTPOST_PRISONER_SULK_ALONE_RANGE)
			return TRUE
	return FALSE

/datum/prisoner_activity/sulk/begin()
	. = ..()
	if(wall)
		prisoner.setDir(get_dir(prisoner, wall))
	prisoner.add_offsets(PRISONER_SULK_OFFSET, y_add = -4)

/datum/prisoner_activity/sulk/tick(seconds)
	if(!wall || get_dist(prisoner, wall) > 1)
		return ACTIVITY_DONE
	if(!stared && prob(10))
		stared = TRUE
		prisoner.manual_emote("stares at the wall.")
	return ..()

/datum/prisoner_activity/sulk/finish()
	prisoner?.remove_offsets(PRISONER_SULK_OFFSET)
	return ..()

// ===== THE PRISON =====

/datum/outpost_prison
	/// REF() of the members who were in the cell block at the last look
	var/list/ambience_members_inside = list()
	/// Seconds towards the next beat of a brewing riot's chant, and the beats so far
	var/ambience_chant_clock = 0
	var/ambience_chant_beats = 0
	/// The rioters have roared for the riot going on
	var/ambience_roared = FALSE
	/// Between heads turning at a member coming in
	COOLDOWN_DECLARE(ambience_notice_cooldown)

/// Notices, hums and whispers, the brewing riot's chant and the riot's roar, once a second (after trouble has set the stage)
/datum/outpost_prison/proc/ambience_tick(seconds)
	var/z = wing_z()
	note_people_inside((z && z <= length(SSmobs.clients_by_zlevel)) ? SSmobs.clients_by_zlevel[z] : list())
	yard_sounds_tick(seconds)
	chant_tick(seconds)
	roar_tick()

/datum/outpost_prison/proc/ambience_destroy()
	ambience_members_inside = list()

/**
 * Whether `speaker`'s line for `context` is dropped because the yard has gone quiet (a restless
 * wing); TRUE drops it. Small talk, remarks to staff, conversations and chatter about what they
 * are doing go quiet; complaints and threats about the wing still get said.
 */
/datum/outpost_prison/proc/speech_hushed(mob/living/basic/outpost_prisoner/speaker, context)
	if(stage != PRISON_STAGE_RESTLESS)
		return FALSE
	var/static/list/always_hushed = list("idle", "staff_near", "conversation")
	if(context in always_hushed)
		return TRUE
	var/static/list/still_said = list("restless", "grumbling", "locked_in", "hatch_wait", "riot_bystander")
	var/datum/prisoner_activity/doing = speaker?.activity
	return !!(doing?.context && doing.context == context && !(context in still_said))

// ----- the yard notices you -----

/**
 * Of `people` (the players on the wing's level), the members of the wing awake in the cell block.
 * One who was not there at the last look turns heads, at most once per OUTPOST_PRISON_NOTICE_GAP.
 * Returns how many prisoners reacted.
 */
/datum/outpost_prison/proc/note_people_inside(list/people)
	var/list/now = list()
	var/mob/living/newcomer
	for(var/mob/living/person in people)
		if(QDELETED(person) || person.stat != CONSCIOUS || is_outpost_prisoner(person) || !in_cell_block(person) || !is_member(person))
			continue
		var/key = REF(person)
		now[key] = TRUE
		if(!newcomer && !ambience_members_inside[key])
			newcomer = person
	ambience_members_inside = now
	if(!newcomer || !COOLDOWN_FINISHED(src, ambience_notice_cooldown))
		return 0
	COOLDOWN_START(src, ambience_notice_cooldown, OUTPOST_PRISON_NOTICE_GAP)
	return yard_notices(newcomer)

/**
 * `member` walked into the cell block. Prisoners who can see them, awake and free, who have not
 * looked round in the last OUTPOST_PRISONER_NOTICE_COOLDOWN, turn to look. By mood and by what the
 * yard thinks of them: content ones (or anyone, for a fair hand) say hello or nod, sour ones (or
 * anyone, for a brute) stare and go quiet, the rest only look. In a restless wing one of them says
 * so. One spoken line and OUTPOST_PRISON_NOTICE_MAX_EMOTES emotes at most, so three people coming
 * and going never floods the chat. Returns how many reacted.
 */
/datum/outpost_prison/proc/yard_notices(mob/living/member)
	var/label = staff_label(member)
	var/restless = stage == PRISON_STAGE_RESTLESS
	var/spoken = FALSE
	var/emotes = 0
	var/reacted = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in shuffle(prisoners))
		if(!prisoner.ai_running() || !prisoner.routine_allowed() || prisoner.activity?.sleeping)
			continue
		if(!COOLDOWN_FINISHED(prisoner, ambience_notice_cooldown))
			continue
		if(get_dist(prisoner, member) > OUTPOST_PRISONER_NOTICE_RANGE || !(member in view(OUTPOST_PRISONER_NOTICE_RANGE, prisoner)))
			continue
		COOLDOWN_START(prisoner, ambience_notice_cooldown, OUTPOST_PRISONER_NOTICE_COOLDOWN)
		reacted++
		prisoner.face_atom(member)
		pause_chat_for_notice(prisoner)
		if(restless && !spoken && prisoner.say_to_staff("staff_enters_restless", member))
			spoken = TRUE
			continue
		if(label == "brute" || prisoner.mood < OUTPOST_PRISONER_NOTICE_STARE_MOOD)
			prisoner.speech_cooldown = max(prisoner.speech_cooldown, world.time + OUTPOST_PRISONER_NOTICE_STARE_HUSH)
			if(emotes < OUTPOST_PRISON_NOTICE_MAX_EMOTES)
				emotes++
				prisoner.manual_emote("stares at [member].")
			continue
		if(label == "fair" || prisoner.mood >= OUTPOST_PRISONER_NOTICE_GREET_MOOD)
			if(!spoken && prob(OUTPOST_PRISONER_NOTICE_GREET_CHANCE) && prisoner.say_to_staff("greet_staff", member))
				spoken = TRUE
				// That was their greeting; the reputation greeting (outpost_prison_social.dm) waits its gap.
				var/greeted_key = rep_key(member)
				if(greeted_key)
					LAZYSET(prisoner.rep_greeted, greeted_key, world.time)
			else if(emotes < OUTPOST_PRISON_NOTICE_MAX_EMOTES)
				emotes++
				prisoner.manual_emote(pick("nods at [member].", "waves at [member]."))
	return reacted

/// A chat they are in waits a moment while they look over
/datum/outpost_prison/proc/pause_chat_for_notice(mob/living/basic/outpost_prisoner/prisoner)
	var/datum/prisoner_activity/chat/talk = prisoner.activity
	if(!istype(talk))
		return
	if(istype(talk, /datum/prisoner_activity/chat/listen))
		var/mob/living/basic/outpost_prisoner/talker = talk.chat_partner()
		talk = talker?.activity
		if(!istype(talk) || istype(talk, /datum/prisoner_activity/chat/listen))
			return
	talk.next_exchange = max(talk.next_exchange, world.time + OUTPOST_PRISONER_NOTICE_CHAT_PAUSE)

// ----- humming and huddles -----

/// Content prisoners now and then hum; while the wing is restless, the ones gathered in the yard whisper among themselves
/datum/outpost_prison/proc/yard_sounds_tick(seconds)
	var/huddling = stage == PRISON_STAGE_RESTLESS && !riot_imminent && !riot_active
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase != PRISONER_PRESENT || prisoner.stat != CONSCIOUS || !prisoner.ai_running())
			continue
		if(huddling && istype(prisoner.activity, /datum/prisoner_activity/gather))
			if(prob(OUTPOST_PRISONER_HUDDLE_CHANCE * seconds))
				try_huddle(prisoner)
			continue
		if(prob(100 * seconds / OUTPOST_PRISONER_HUM_ONE_IN))
			try_hum(prisoner)

/**
 * A content cheerful, chatty or quiet prisoner, awake and free, hums to themself, at most once per
 * OUTPOST_PRISONER_HUM_COOLDOWN. Returns TRUE if they did.
 */
/datum/outpost_prison/proc/try_hum(mob/living/basic/outpost_prisoner/prisoner)
	var/static/list/hummers = list("cheerful", "chatty", "quiet")
	if(prisoner.mood < OUTPOST_PRISONER_HUM_MOOD || !(prisoner.personality in hummers))
		return FALSE
	if(!prisoner.ai_running() || !prisoner.routine_allowed() || prisoner.activity?.sleeping || !COOLDOWN_FINISHED(prisoner, ambience_hum_cooldown))
		return FALSE
	COOLDOWN_START(prisoner, ambience_hum_cooldown, OUTPOST_PRISONER_HUM_COOLDOWN)
	prisoner.manual_emote("hums to [prisoner.p_themselves()].")
	playsound(prisoner, 'sound/mobs/humanoids/human/whistle/whistle1.ogg', 15, TRUE, -3)
	return TRUE

/// A gathered prisoner whispers a huddle line, at most once per OUTPOST_PRISONER_HUDDLE_GAP. Returns TRUE if they did.
/datum/outpost_prison/proc/try_huddle(mob/living/basic/outpost_prisoner/prisoner)
	if(!COOLDOWN_FINISHED(prisoner, ambience_huddle_cooldown))
		return FALSE
	var/line = prisoner.pick_line("huddle")
	if(!line)
		return FALSE
	COOLDOWN_START(prisoner, ambience_huddle_cooldown, OUTPOST_PRISONER_HUDDLE_GAP)
	prisoner.last_line = line
	prisoner.whisper(line)
	return TRUE

// ----- the chant and the roar -----

/**
 * While a riot brews (riot_imminent), a beat every OUTPOST_PRISON_CHANT_GAP seconds, every
 * OUTPOST_PRISON_CHANT_GAP_LATE in the hold's last OUTPOST_PRISON_CHANT_LATE_WINDOW seconds. It
 * stops the tick the riot starts or the brewing clears. Returns TRUE on a beat.
 */
/datum/outpost_prison/proc/chant_tick(seconds)
	if(!riot_imminent || riot_active)
		ambience_chant_clock = 0
		ambience_chant_beats = 0
		return FALSE
	ambience_chant_clock += seconds
	var/gap = riot_hold > PRISON_RIOT_HOLD - OUTPOST_PRISON_CHANT_LATE_WINDOW ? OUTPOST_PRISON_CHANT_GAP_LATE : OUTPOST_PRISON_CHANT_GAP
	if(ambience_chant_clock < gap)
		return FALSE
	ambience_chant_clock = 0
	chant_beat()
	return TRUE

/**
 * One beat: up to OUTPOST_PRISON_CHANT_SLAMMERS of the prisoners gathered in the yard slam the
 * mess table or the door beside them, and every OUTPOST_PRISON_CHANT_LINE_EVERY beats one of them
 * chants, whatever the wing's speech cooldown. Returns who slammed.
 */
/datum/outpost_prison/proc/chant_beat()
	ambience_chant_beats++
	var/list/gathered = list()
	var/list/slammers = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in shuffle(prisoners))
		var/datum/prisoner_activity/gather/gathering = prisoner.activity
		if(!istype(gathering) || !gathering.started || gathering.spot || !prisoner.ai_running() || !prisoner.routine_allowed())
			continue
		gathered += prisoner
		if(length(slammers) >= OUTPOST_PRISON_CHANT_SLAMMERS)
			continue
		var/atom/slammed = chant_surface(prisoner)
		if(!slammed)
			continue
		slammers += prisoner
		prisoner.face_atom(slammed)
		playsound(slammed, 'sound/effects/tableslam.ogg', OUTPOST_PRISON_CHANT_VOLUME, TRUE, OUTPOST_PRISON_CHANT_RANGE)
		slammed.Shake(1, 1, 0.3 SECONDS)
	if(!(ambience_chant_beats % OUTPOST_PRISON_CHANT_LINE_EVERY))
		var/list/voices = length(slammers) ? slammers : gathered
		if(length(voices))
			var/mob/living/basic/outpost_prisoner/voice = pick(voices)
			voice.say_context("riot_chant")
	return slammers

/// A mess table or a door beside `prisoner` to slam on, or null
/datum/outpost_prison/proc/chant_surface(mob/living/basic/outpost_prisoner/prisoner)
	var/turf/here = get_turf(prisoner)
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(here, direction)
		if(!beside)
			continue
		if(is_mess_table(beside))
			for(var/obj/structure/table/table in beside)
				if(!istype(table, /obj/structure/table/reinforced/prison_hatch))
					return table
		var/obj/machinery/door/airlock/door = locate() in beside
		if(door)
			return door
	return null

/// The tick a riot starts, every rioter on their feet roars (OUTPOST_PRISON_ROAR_MAX at most), once per riot. Returns how many did.
/datum/outpost_prison/proc/roar_tick()
	if(!riot_active)
		ambience_roared = FALSE
		return 0
	if(ambience_roared)
		return 0
	ambience_roared = TRUE
	var/roared = 0
	for(var/mob/living/basic/outpost_prisoner/rioter in prisoners)
		if(!rioter.is_rioting() || rioter.stat != CONSCIOUS || rioter.phase != PRISONER_PRESENT || !rioter.ai_running())
			continue
		if(rioter.say_context("riot_roar"))
			roared++
		if(roared >= OUTPOST_PRISON_ROAR_MAX)
			break
	return roared

#undef PRISONER_SULK_OFFSET
#undef ACTIVITY_DONE
