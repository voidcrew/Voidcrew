/**
 * # Outpost jobs: break-ins
 *
 * Owner: P5. Spec 6.3 (the safe and its ledger) and 6.5 (a bag out of the evidence locker). Both jobs have one
 * deed: the goods are out in a mind's hands (mark_deed()), and the crew then takes them to a fixer. The safe is
 * excluded from ship saves (GLOB.outpost_checkpoint_excluded).
 *
 * The safe job brings:
 * - /obj/structure/safe/fixer: tg's own safe, two tumblers, the ledger inside. Opening it and taking the ledger out
 *   are each LOCKER_THEFT, once per thief; standing at the dial is nothing.
 * - the courier firm's clerk (.../drinker/job_clerk): off the lift, through the checkpoint, to the safe to write in his
 *   book, then to the bar like any drinker. The combination is on a slip in his pocket. Lifting it from him awake is a
 *   LOCKER_THEFT with him as the victim; asleep, out cold or dead he does not notice.
 *
 * The evidence job puts a sealed bag into police.evidence_locker through the locker's own take_evidence(): the locker
 * watches every item put in that way until a hand takes it out, awake or not, whatever state the lock is in, and
 * reports whoever takes it for LOCKER_THEFT (evidence_locker.dm). This job adds only the deed watch.
 */

/// What the clerk looks like, in the words of his outfit's own items (the offer's {look} and the note)
#define BREAKIN_CLERK_LOOK "charcoal suit, flat cap"
/// Where the safe stands, as a fixer would say it (the offer's {place})
#define BREAKIN_SAFE_PLACE "the back wall"
/// Where the bag is kept, as a fixer would say it (the offer's {place})
#define BREAKIN_LOCKER_PLACE "the evidence locker"

/// `text` cut to `bound` characters, with three dots at the cut. Not encoded.
/proc/breakin_cut(text, bound)
	text = "[text]"
	if(length_char(text) <= bound)
		return text
	return "[copytext_char(text, 1, bound - 2)]..."

/// The station clock at `when`, as "14:20"
/proc/breakin_clock(when)
	return station_time_timestamp("hh:mm", when)

// =========================================================================
// THE JOBS
// =========================================================================

/datum/mission/fixer_job/breakin
	job_kind = FIXER_JOB_BREAKIN
	base_pay = FIXER_PAY_BREAKIN
	duration = FIXER_TIME_BREAKIN
	trust_tier = FIXER_TRUST_TIER1
	slate_weight = FIXER_WEIGHT_BREAKIN
	goods_type = /obj/item/mission_recovery/fixer_goods/ledger
	scene_crimes = list(OUTPOST_CRIME_LOCKER_THEFT)
	/// Weakref to the safe
	var/datum/weakref/safe_ref
	/// Weakref to the clerk
	var/datum/weakref/clerk_ref
	/// Weakref to the goods whose hands the job watches (the ledger, or the bag)
	var/datum/weakref/watched_ref
	/// The clerk's name and gender, rolled when first needed (the offer names him before he exists)
	var/clerk_name
	var/clerk_gender

/datum/mission/fixer_job/breakin/allowed_at(obj/structure/overmap/trader_outpost/outpost, datum/voidcrew_crew_record/crew)
	return !QDELETED(outpost) && !QDELETED(outpost.police)

/// The clerk's name and gender, rolled once
/datum/mission/fixer_job/breakin/proc/roll_clerk()
	if(clerk_name)
		return
	clerk_gender = pick(MALE, FEMALE)
	clerk_name = generate_random_name(clerk_gender)

/// The deadline's clock time: from the accept if the job has started, from now if it is only an offer
/datum/mission/fixer_job/breakin/proc/deadline_clock()
	return breakin_clock((time_started || world.time) + duration)

/datum/mission/fixer_job/breakin/offer_tokens()
	roll_clerk()
	return list(
		FIXER_TOKEN_NAME = html_encode(breakin_cut(clerk_name, FIXER_BOUND_NAME)),
		FIXER_TOKEN_LOOK = html_encode(breakin_cut(BREAKIN_CLERK_LOOK, FIXER_BOUND_LOOK)),
		FIXER_TOKEN_CLOCK = deadline_clock(),
		FIXER_TOKEN_PLACE = html_encode(breakin_cut(BREAKIN_SAFE_PLACE, FIXER_BOUND_PLACE)),
	)

/datum/mission/fixer_job/breakin/note_lines()
	roll_clerk()
	return list(
		html_encode(breakin_cut("Courier firm ledger. Deposit safe by [BREAKIN_SAFE_PLACE].", FIXER_BOUND_NOTE_LINE)),
		html_encode(breakin_cut("Their clerk: [clerk_name], [BREAKIN_CLERK_LOOK].", FIXER_BOUND_NOTE_LINE)),
		"Be done by [deadline_clock()].",
	)

// ----- staging -----

/datum/mission/fixer_job/breakin/stage()
	var/obj/structure/overmap/trader_outpost/outpost = job_outpost
	if(QDELETED(outpost) || QDELETED(outpost.police))
		return FALSE
	// The safe stands against a wall, as far from the lift as the floor allows
	var/turf/safe_spot = breakin_spot(FIXER_SPOT_WALL, far_from_lift()) || breakin_spot(FIXER_SPOT_WALL)
	// The clerk steps off the lift like any visitor
	var/turf/arrive_spot = breakin_spot(FIXER_SPOT_ARRIVE) || SSambient_npcs.lift_arrival_turf(outpost)
	if(!safe_spot || !arrive_spot)
		return FALSE
	var/obj/structure/safe/fixer/safe = place_safe(safe_spot)
	if(!safe || !place_clerk(arrive_spot, safe))
		unstage()
		return FALSE
	return TRUE

/// One free turf of `kind` at the job's outpost, nearest `near` if given, or null
/datum/mission/fixer_job/breakin/proc/breakin_spot(kind, atom/near)
	var/list/spots = fixer_job_spot(job_outpost, kind, near, 1)
	return length(spots) ? spots[1] : null

/// The public floor tile farthest from the lift, or null if the outpost has no floor or lift to measure from
/datum/mission/fixer_job/breakin/proc/far_from_lift()
	var/obj/structure/overmap/trader_outpost/outpost = job_outpost
	var/datum/ambient_place/outpost/place = SSambient_npcs.outposts?[outpost]
	if(!place || !length(outpost.lobby_alcove_turfs))
		return null
	var/turf/lift = outpost.lobby_alcove_turfs[1]
	var/turf/far
	var/far_distance = -1
	for(var/turf/tile as anything in place.get_loiter_floor())
		if(tile.z != lift.z)
			continue
		var/distance = get_dist(tile, lift)
		if(distance > far_distance)
			far = tile
			far_distance = distance
	return far

/// Builds the safe on `where` with the ledger inside, and watches the ledger
/datum/mission/fixer_job/breakin/proc/place_safe(turf/where)
	var/obj/structure/safe/fixer/safe = new(where)
	safe.job_ref = WEAKREF(src)
	safe_ref = WEAKREF(safe)
	track(safe, TRUE)
	var/obj/item/mission_recovery/fixer_goods/ledger/ledger = new(safe)
	safe.space += ledger.w_class
	hold_goods(ledger)
	return safe

/// Binds `goods` to the job, tracks it and watches for the first hand that takes it
/datum/mission/fixer_job/breakin/proc/hold_goods(obj/item/mission_recovery/fixer_goods/goods)
	goods.bind_job(src)
	goods_ref ||= WEAKREF(goods)
	track(goods, FALSE)
	stop_watching()
	watched_ref = WEAKREF(goods)
	RegisterSignal(goods, COMSIG_ITEM_EQUIPPED, PROC_REF(on_goods_equipped))

/// The goods are no longer watched
/datum/mission/fixer_job/breakin/proc/stop_watching()
	var/obj/item/goods = watched_ref?.resolve()
	if(goods)
		UnregisterSignal(goods, COMSIG_ITEM_EQUIPPED)

/// Builds the clerk at `where` (off the lift), with the combination in his pocket and the safe to mind. Null if it could not be.
/datum/mission/fixer_job/breakin/proc/place_clerk(turf/where, obj/structure/safe/fixer/safe)
	roll_clerk()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk/clerk = ambient_build_npc(/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk, where, null, list("name" = clerk_name, "gender" = clerk_gender))
	if(QDELETED(clerk))
		return null
	clerk_ref = WEAKREF(clerk)
	fixer_job_npc_setup(clerk, src)
	clerk.job_ref = WEAKREF(src)
	clerk.safe_ref = WEAKREF(safe)
	var/obj/item/paper/fixer_slip/slip = new(get_turf(clerk))
	slip.write_for(safe)
	if(clerk.carry_slip(slip))
		track(slip, FALSE)
	else
		qdel(slip)
	clerk.fade_in()
	ambient_cross_checkpoint_on_arrival(clerk, job_outpost)
	return clerk

// ----- the deed -----

/// The ledger or the bag went into a mob's hands
/datum/mission/fixer_job/breakin/proc/on_goods_equipped(obj/item/source, mob/user, slot)
	SIGNAL_HANDLER
	if(deed_done || !isliving(user) || !(slot & ITEM_SLOT_HANDS))
		return
	INVOKE_ASYNC(src, PROC_REF(goods_taken), user)

/// `taker` has the goods in hand: taking the ledger out of a safe is a theft too; then the deed is theirs
/datum/mission/fixer_job/breakin/proc/goods_taken(mob/living/taker)
	if(QDELETED(src) || deed_done || QDELETED(taker))
		return
	var/obj/structure/safe/fixer/safe = safe_ref?.resolve()
	if(!QDELETED(safe))
		safe.report_theft(taker)
	mark_deed(taker)

// ----- the end -----

/datum/mission/fixer_job/breakin/on_deadline()
	// The clerk empties the safe and leaves by the lift
	remove_goods()
	send_clerk_away()
	return ..()

/datum/mission/fixer_job/breakin/unstage()
	stop_watching()
	remove_goods()
	send_clerk_away()
	var/obj/structure/safe/fixer/safe = safe_ref?.resolve()
	if(!QDELETED(safe))
		// What a crew put in it is theirs: on the floor, before the safe goes
		safe.empty_foreign()
		qdel(safe)
	return ..()

/// Deletes the goods wherever they are
/datum/mission/fixer_job/breakin/proc/remove_goods()
	var/obj/item/goods = watched_ref?.resolve()
	if(!QDELETED(goods))
		qdel(goods)

/**
 * The clerk is no longer the job's: he goes about his business, out by the lift while anyone watches. He is taken
 * off the job's atoms so the job's cleanup does not make him vanish in front of them. A dead clerk is the outpost's
 * dead, like any other.
 */
/datum/mission/fixer_job/breakin/proc/send_clerk_away()
	if(!clerk_ref)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk/clerk = clerk_ref.resolve()
	if(islist(job_atoms))
		job_atoms -= clerk_ref
	clerk_ref = null
	if(QDELETED(clerk))
		return
	clerk.job_ref = null
	clerk.safe_ref = null
	if(clerk.stat != DEAD)
		clerk.speak_context("empty", null, TRUE)
		clerk.fade_out()

/datum/mission/fixer_job/breakin/evidence
	job_kind = FIXER_JOB_EVIDENCE
	base_pay = FIXER_PAY_EVIDENCE
	duration = FIXER_TIME_EVIDENCE
	trust_tier = FIXER_TRUST_TIER2
	slate_weight = FIXER_WEIGHT_EVIDENCE
	goods_type = /obj/item/mission_recovery/fixer_goods/evidence
	/// The number on the bag, rolled when first needed
	var/case_number

/datum/mission/fixer_job/breakin/evidence/allowed_at(obj/structure/overmap/trader_outpost/outpost, datum/voidcrew_crew_record/crew)
	return ..() && !QDELETED(outpost.police.get_evidence_locker())

/datum/mission/fixer_job/breakin/evidence/proc/roll_case()
	case_number ||= rand(1000, 9999)

/datum/mission/fixer_job/breakin/evidence/offer_tokens()
	roll_case()
	return list(
		FIXER_TOKEN_NAME = "case [case_number]",
		FIXER_TOKEN_LOOK = html_encode(breakin_cut("a sealed clear bag", FIXER_BOUND_LOOK)),
		FIXER_TOKEN_CLOCK = deadline_clock(),
		FIXER_TOKEN_PLACE = html_encode(breakin_cut(BREAKIN_LOCKER_PLACE, FIXER_BOUND_PLACE)),
	)

/datum/mission/fixer_job/breakin/evidence/note_lines()
	roll_case()
	return list(
		"Sealed bag, case [case_number].",
		"It is in [BREAKIN_LOCKER_PLACE]. Just the bag.",
		"Be done by [deadline_clock()].",
	)

/datum/mission/fixer_job/breakin/evidence/stage()
	var/obj/structure/overmap/trader_outpost/outpost = job_outpost
	if(QDELETED(outpost) || QDELETED(outpost.police))
		return FALSE
	var/obj/structure/closet/secure_closet/outpost_evidence/locker = outpost.police.get_evidence_locker()
	if(QDELETED(locker))
		return FALSE
	if(!place_bag(locker))
		unstage()
		return FALSE
	return TRUE

/// Puts a sealed bag into `locker` the way an arrest's evidence goes in, so the locker watches it until a hand takes it out. Null if it could not be.
/datum/mission/fixer_job/breakin/evidence/proc/place_bag(obj/structure/closet/secure_closet/outpost_evidence/locker)
	roll_case()
	var/obj/item/mission_recovery/fixer_goods/evidence/bag = new(get_turf(locker))
	bag.set_case(case_number)
	if(!locker.take_evidence(bag))
		qdel(bag)
		return null
	hold_goods(bag)
	return bag

/datum/mission/fixer_job/breakin/evidence/on_deadline()
	// It has gone upstairs: the locker watches it no more
	unwatch_bag()
	return ..()

/datum/mission/fixer_job/breakin/evidence/unstage()
	unwatch_bag()
	return ..()

/// The locker lets go of the bag before it is deleted
/datum/mission/fixer_job/breakin/evidence/proc/unwatch_bag()
	var/obj/item/bag = watched_ref?.resolve()
	var/obj/structure/closet/secure_closet/outpost_evidence/locker = job_outpost?.police?.evidence_locker
	if(bag && !QDELETED(locker))
		locker.unwatch(bag)

// =========================================================================
// THE SAFE
// =========================================================================

/// The safe the job brings: tg's own, two tumblers, the ledger inside
/obj/structure/safe/fixer
	name = "deposit safe"
	desc = "A squat deposit safe with a courier firm's seal on the door."
	move_resist = INFINITY
	set_dir_on_move = FALSE
	/// Weakref to the job whose safe this is
	var/datum/weakref/job_ref
	/// Weakrefs to the minds already reported for opening it or taking from it
	var/list/thieves

/obj/structure/safe/fixer/Destroy()
	empty_foreign()
	job_ref = null
	thieves = null
	return ..()

/// Whoever opens it is reported (once); the dial, the stethoscope and the blasts are tg's
/obj/structure/safe/fixer/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	var/was_open = open
	. = ..()
	if(action == "open" && open && !was_open && isliving(usr))
		report_theft(usr)

/// The outpost this safe stands in: the job's, or the one its tile is in
/obj/structure/safe/fixer/proc/job_outpost()
	var/datum/mission/fixer_job/job = job_ref?.resolve()
	return job?.job_outpost || get_trader_outpost_for_turf(get_turf(src))

/// `thief` opened it or took from it: a locker theft for the outpost's police, once per person. The witness test is the police's.
/obj/structure/safe/fixer/proc/report_theft(mob/living/thief)
	if(!thief?.mind)
		return
	var/datum/weakref/key = WEAKREF(thief.mind)
	if(LAZYACCESS(thieves, key))
		return
	LAZYSET(thieves, key, world.time)
	var/obj/structure/overmap/trader_outpost/outpost = job_outpost()
	outpost?.police?.report_crime(thief, OUTPOST_CRIME_LOCKER_THEFT, src)

/// Sets everything but the job's own goods on the floor in front of it, for whoever put it there
/obj/structure/safe/fixer/proc/empty_foreign()
	var/turf/where = get_turf(src)
	if(!where)
		return
	for(var/atom/movable/thing in contents.Copy())
		if(istype(thing, /obj/item/mission_recovery/fixer_goods))
			continue
		thing.forceMove(where)
	space = 0

// =========================================================================
// THE GOODS
// =========================================================================

/// The ledger inside the safe
/obj/item/mission_recovery/fixer_goods/ledger
	name = "sealed ledger"
	desc = "A heavy ledger with a courier firm's seal on the cover."
	icon = 'icons/obj/service/library.dmi'
	icon_state = "book3"
	inhand_icon_state = null
	lefthand_file = null
	righthand_file = null
	w_class = WEIGHT_CLASS_SMALL

/// The evidence bag in the locker
/obj/item/mission_recovery/fixer_goods/evidence
	name = "sealed evidence bag"
	desc = "A clear bag with a security seal and a case number."
	icon = 'icons/obj/storage/storage.dmi'
	icon_state = "evidenceobj"
	inhand_icon_state = null
	lefthand_file = null
	righthand_file = null
	w_class = WEIGHT_CLASS_TINY
	/// The number on the seal
	var/case_number

/// Puts `number` on the seal
/obj/item/mission_recovery/fixer_goods/evidence/proc/set_case(number)
	case_number = number
	desc = "A clear bag with a security seal. Case [number]."

/// The combination, on a slip of paper
/obj/item/paper/fixer_slip
	name = "paper slip"
	desc = "A slip of paper with a couple of numbers on it."
	icon_state = "paperslip"
	can_become_message_in_bottle = FALSE

/// Writes `safe`'s two numbers on it, in the order the dial takes them: left to the first, right to the second
/obj/item/paper/fixer_slip/proc/write_for(obj/structure/safe/fixer/safe)
	add_raw_text("L [safe.tumblers[1]]  R [safe.tumblers[2]]")
	update_appearance()

/**
 * Lifted off the clerk while he is awake, he notices. Asleep, out cold or dead he does not.
 * Pocket stripping ends here (strippable.dm finish_unequip_mob()).
 */
/obj/item/paper/fixer_slip/doStrip(mob/stripper, mob/owner)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk/clerk = owner
	var/noticed = istype(clerk) && clerk.stat == CONSCIOUS
	. = ..()
	if(. && noticed)
		clerk.slip_lifted(stripper, src)

// =========================================================================
// THE CLERK
// =========================================================================

/// A courier firm's clerk: charcoal suit, flat cap
/datum/outfit/ambient_customer/clerk
	name = "Outpost customer (courier clerk)"
	uniform = /obj/item/clothing/under/suit/charcoal
	suit = null
	head = /obj/item/clothing/head/flatcap
	shoes = /obj/item/clothing/shoes/laceup

/**
 * The courier firm's clerk. He checks the firm's safe, writes it up in his book beside it, and then drinks like any
 * drinker (outpost_patrons.dm): orders, sits, gets chatty, then loud, then sleeps it off. The combination is on a slip
 * in his pocket and goes with him if he leaves alive.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk
	desc = "A courier firm's clerk, here on the firm's business."
	outfit_choices = list(/datum/outfit/ambient_customer/clerk)
	/// Weakref to the job he belongs to
	var/datum/weakref/job_ref
	/// Weakref to the safe he minds
	var/datum/weakref/safe_ref
	/// He has been to the safe
	var/checked = FALSE

/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk/Initialize(mapload, datum/human_npc_order/order)
	. = ..()
	// ambient_dialogue_lines() reads only the ambient strings directory: this file goes into the cache first
	load_strings_file(FIXER_STRINGS_BREAKIN, FIXER_STRINGS_DIR)

/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk/Destroy()
	job_ref = null
	safe_ref = null
	return ..()

/// His own lines for the safe and the slip; everything else is any drinker's
/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk/get_lines(context)
	var/list/own = ambient_dialogue_lines(FIXER_STRINGS_BREAKIN, "clerk", context)
	return length(own) ? own : ..()

/// The safe first, once; then the drinker's night
/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk/pick_activity()
	var/obj/structure/safe/fixer/safe = safe_ref?.resolve()
	if(!checked && !QDELETED(safe))
		checked = TRUE
		var/datum/ambient_activity/check = start_activity(new /datum/ambient_activity/clerk_check(src, safe))
		if(check)
			return check
	return ..()

/// Puts the slip in a pocket. FALSE if he has none free.
/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk/proc/carry_slip(obj/item/paper/fixer_slip/slip)
	return equip_to_slot_if_possible(slip, ITEM_SLOT_LPOCKET, disable_warning = TRUE) || equip_to_slot_if_possible(slip, ITEM_SLOT_RPOCKET, disable_warning = TRUE)

/// The slip goes with him when he leaves alive (a body drops it, like any paper)
/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk/npc_drop_not_gear()
	if(stat != DEAD)
		for(var/obj/item/paper/fixer_slip/slip in get_all_contents())
			qdel(slip)
	return ..()

/// The outpost he is in: the job's, or the one his place is, or the one his tile is in
/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk/proc/clerk_outpost()
	var/datum/mission/fixer_job/job = job_ref?.resolve()
	if(job?.job_outpost)
		return job.job_outpost
	var/datum/ambient_place/outpost/outpost_place = place
	return (istype(outpost_place) ? outpost_place.outpost() : null) || get_trader_outpost_for_turf(get_turf(src))

/// `stripper` lifted the slip out of his pocket while he was awake: he says so, and it is a locker theft with him as the victim
/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk/proc/slip_lifted(mob/stripper, obj/item/paper/fixer_slip/slip)
	if(!isliving(stripper) || QDELETED(src))
		return
	if(!buckled)
		face_atom(stripper)
	speak_context("slip_taken", stripper, TRUE)
	var/obj/structure/overmap/trader_outpost/outpost = clerk_outpost()
	outpost?.police?.report_crime(stripper, OUTPOST_CRIME_LOCKER_THEFT, src, slip)

/**
 * Checking the safe: he goes to the tile in front of it, takes out his book (a clipboard in his hand), writes for
 * half a minute and puts it away.
 */
/datum/ambient_activity/clerk_check
	name = "checking the safe"
	duration_low = 25 SECONDS
	duration_high = 40 SECONDS
	/// The walk to the safe failed
	var/given_up = FALSE

/datum/ambient_activity/clerk_check/setup()
	var/obj/structure/safe/fixer/safe = anchor()
	if(!safe)
		return FALSE
	var/turf/stand = doer.free_tile_beside(safe, 1, failed_spots)
	if(!stand)
		return FALSE
	go_to(stand)
	return TRUE

/datum/ambient_activity/clerk_check/arrive()
	if(given_up)
		return
	var/atom/safe = anchor()
	if(safe && !doer.buckled)
		doer.face_atom(safe)
	set_duration()
	next_line = world.time + rand(6 SECONDS, 12 SECONDS)
	doer.set_held(/obj/item/clipboard)
	doer.speak_context("check", null, TRUE)

/datum/ambient_activity/clerk_check/act(seconds)
	if(given_up)
		return AMBIENT_STEP_DONE
	if(world.time >= next_line)
		next_line = world.time + rand(10 SECONDS, 18 SECONDS)
		if(!doer.speak_context("write"))
			doer.manual_emote("writes a line in the book.")
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/clerk_check/finish()
	if(!QDELETED(doer))
		doer.set_held(null)
	return ..()

/datum/ambient_activity/clerk_check/spot_unreachable()
	. = ..()
	given_up = TRUE
	ends_at = world.time

#undef BREAKIN_CLERK_LOOK
#undef BREAKIN_SAFE_PLACE
#undef BREAKIN_LOCKER_PLACE
