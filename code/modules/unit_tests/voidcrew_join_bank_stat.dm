/**
 * # Join, bank and stat contracts — the 2026-08 upgrade's live breaks
 *
 * Five separate outages shipped to production on the tg-2026-08 merge, all of them in
 * fork code that overrides an upstream proc whose *contract* changed underneath it. None
 * of them was a compile error, none had any test coverage, and three of them were
 * completely silent in game. Each test below names the incident it pins.
 *
 * 1. **No crewmate ever reached a cryopod, on any ship** (prod round-16, 13 runtimes).
 *    Upstream now lets `/atom/JoinPlayerHere()` be handed a bare TYPE PATH and returns
 *    the mob it instantiates (`/datum/job/get_spawn_mob()`, `_job.dm:526`, passes
 *    `spawn_type`). The fork's cryopod override used the raw argument instead of the
 *    parent's return, so it ran `SetStun()` on a typepath and `close_machine()` aborted.
 *    Fixed at `voidcrew/modules/cryo/machine.dm:95-102`.
 * 2. **`stat`'s UNCONSCIOUS value was deleted upstream** (tg #97041, 7357a3441ff). The
 *    enum is now exactly STABLE/SOFT_CRIT/HARD_CRIT/DEAD and being knocked out is
 *    `TRAIT_KNOCKEDOUT`, not a stat. Every fork `stat != CONSCIOUS` was mechanically
 *    renamed to `stat != STABLE`, which kept the crit/dead half and **silently dropped
 *    the unconscious half** — sleeping, sedated and flashbanged players read as STABLE.
 *    44 sites across 13 modules were migrated to `IS_UNCONSCIOUS_OR_CRIT()`.
 * 3. **Every ship bank notification was dead, fleet-wide.** `bank_account.bank_cards`
 *    became a lazylist (null until the first card) with `set_account()` as its API. The
 *    fork's `register_crewmember()` still did `bank_cards += card`, which on a null
 *    lazylist stores the card *itself* rather than a list — `LAZYLEN()` then reads 0 and
 *    `bank_card_talk()` bails on every payday, transfer, bounty and CRAB-17.
 *    Fixed at `ship.dm:996-1004`.
 * 4. **`item_export_value()` returned 0 for every item in the game.**
 *    `/datum/export/applies_to()`'s third argument became a *list* of markets; the fork
 *    passed the bare `EXPORT_MARKET_STATION` string, and iterating a string yields zero
 *    iterations, so nothing ever matched. The Fence's Eye said "nobody's buying" about
 *    everything.
 * 5. **Bosses attacked from inside their locked states / the Mimic swung from disguise.**
 *    `BASIC_MOB_CONTINUE_ATTACK_CHAIN` is 0 and `melee_attack()` reads *any truthy value*
 *    as "stop", so a fork override returning bare `FALSE` to mean "don't attack" means
 *    exactly the opposite. Four overrides had that polarity inversion.
 *
 * ## Coverage boundaries, stated up front
 *
 * - **There is no `TEST_ASSERT_NO_RUNTIME`.** Where a test's real claim is "this call
 *   does not runtime", it makes the call and relies on the suite's own verdict:
 *   `world.dm` refuses to write `data/logs/ci/clean_run.lk` unless `GLOB.total_runtimes`
 *   is zero, so a runtime raised anywhere in here fails the run even though no assertion
 *   fires. Those spots are commented.
 * - **`get_spawn_mob()` itself cannot be driven without a real client.** It ends in
 *   `spawn_instance.apply_prefs_job(player_client, src)`, and the human override
 *   dereferences `player_client.prefs` unconditionally; a `/client` cannot be
 *   instantiated from DM. So the join test drives the deepest client-free layer —
 *   `JoinPlayerHere()` plus the fork's `close_machine()` override — which is precisely
 *   where the break lived. The client-gated remainder of the path is S1 harness work.
 * - **The cryo *departure* guard is client-gated too** (`try_return_to_cryo()` returns at
 *   `!user.client` before it reaches the wake check), so its stat half is pinned as a
 *   predicate rather than driven. See `voidcrew_cryo_wake_guard` for the detail.
 *
 * Fork defines are unavailable here — unit tests compile at the `code/modules/unit_tests`
 * include position, before `voidcrew/_DEFINES/`. Everything used below (STABLE,
 * IS_UNCONSCIOUS_OR_CRIT, BASIC_MOB_*, ITEM_SLOT_ID, EXPORT_MARKET_STATION) is upstream.
 */

/// Fork source root for the census/lint scans.
#define VC_JBS_FORK_ROOT "voidcrew/"
/// Where the mob health stat enum is declared.
#define VC_JBS_STAT_DEFINES "code/__DEFINES/stat.dm"
/// The one file allowed to compare a raw stat value against STABLE, and how many times.
/// Both are asserted: an allowlist that stops matching is an allowlist that has quietly
/// stopped guarding anything.
#define VC_JBS_STAT_ALLOWLIST_FILE "voidcrew/modules/cyberware/ware_military_body.dm"
#define VC_JBS_STAT_ALLOWLIST_COUNT 3

// Override censuses. Each behavioural sweep below covers a hand-written table of types,
// because DM cannot enumerate the overrides of a proc; these counts make the table's
// completeness assertable, so a fifth override added later fails the sweep that does not
// cover it instead of shipping uncovered.
#define VC_JBS_JOINPLAYERHERE_OVERRIDES 1
#define VC_JBS_CLOSE_MACHINE_OVERRIDES 5
#define VC_JBS_EARLY_MELEE_OVERRIDES 4

// ===========================================================================
// Source-scanning helpers (file-local; the shared ones live in voidcrew_helpers.dm)
// ===========================================================================

/**
 * Counts definitions of `proc_name` under a pre-read fork source tree.
 *
 * A definition is a line that starts at column 1 with a typepath and contains
 * `/<proc_name>(`, which is how every override in this codebase is written. Call sites
 * are indented and so are never counted.
 */
/proc/vc_jbs_count_overrides(list/sources, proc_name)
	var/count = 0
	for(var/path in sources)
		var/text = sources[path]
		if(!findtext(text, "/[proc_name]("))
			continue
		for(var/line in splittext(text, "\n"))
			if(copytext(line, 1, 2) != "/")
				continue
			if(findtext(line, "/[proc_name]("))
				count++
	return count

/// Whether an ascii code is DM whitespace (space or tab).
/proc/vc_jbs_is_space(code)
	return code == 32 || code == 9

/**
 * Whether the `STABLE` token at `position` in `text` is the right-hand side of a
 * comparison against something whose name ends in `stat`.
 *
 * This is the shape the upgrade broke: `stat != CONSCIOUS` was renamed to
 * `stat != STABLE`, which still compiles, still reads sensibly and silently stops
 * covering knocked-out mobs. Assignment (`stat = STABLE`, `set_stat(STABLE)`) is fine and
 * is deliberately not matched — only comparisons are.
 *
 * Deliberately conservative in one direction: any identifier ending in "stat" counts, so
 * `new_stat`, `old_stat` and `patient.stat` all match. Over-matching fails loudly and is
 * cheap to resolve; under-matching is how the original bug shipped.
 */
/proc/vc_jbs_is_stat_comparison(text, position)
	// A standalone token, not the tail of PASSTABLE / UNSTABLE / a longer identifier.
	if(position > 1 && vc_test_is_identifier_char(text2ascii(text, position - 1)))
		return FALSE
	var/after = position + length("STABLE")
	if(after <= length(text) && vc_test_is_identifier_char(text2ascii(text, after)))
		return FALSE

	var/index = position - 1
	while(index >= 1 && vc_jbs_is_space(text2ascii(text, index)))
		index--
	if(index < 1)
		return FALSE

	// The comparison operator. "=" only counts when led by ! = < >, which is what keeps
	// plain assignment out of the results.
	var/code = text2ascii(text, index)
	if(code == 61) // =
		if(index < 2)
			return FALSE
		var/lead = text2ascii(text, index - 1)
		if(lead != 33 && lead != 61 && lead != 60 && lead != 62) // ! = < >
			return FALSE
		index -= 2
	else if(code == 60 || code == 62) // < >
		index--
	else
		return FALSE

	while(index >= 1 && vc_jbs_is_space(text2ascii(text, index)))
		index--
	if(index < 1)
		return FALSE

	// The left-hand identifier, read backwards. A "." terminates it, so `patient.stat`
	// yields "stat".
	var/token_end = index + 1
	while(index >= 1 && vc_test_is_identifier_char(text2ascii(text, index)))
		index--
	var/token = copytext(text, index + 1, token_end)
	if(length(token) < 4)
		return FALSE
	return lowertext(copytext(token, -4)) == "stat"

/**
 * Whether `position` sits inside a DM comment.
 *
 * Block comments are detected by counting unbalanced block-comment openers before the
 * position; line comments by a slash-slash earlier on the same line. (The openers cannot
 * be written out here: DM nests block comments, so a literal one inside this docstring
 * would swallow the rest of the file - which is exactly what it did on the first
 * compile.) The known limitation is a slash-slash inside a string literal
 * earlier on the same line, which would hide a real match — a false negative that has
 * never occurred in this tree and is the safe direction for a scan whose failure mode
 * must not be noise.
 */
/proc/vc_jbs_in_comment(text, position)
	var/before = copytext(text, 1, position)
	// Assembled rather than written out: a literal block-comment opener in DM source
	// starts a comment even inside a string literal, and DM nests them.
	var/opener = "/" + "*"
	var/closer = "*" + "/"
	if(vc_test_count_occurrences(before, opener) > vc_test_count_occurrences(before, closer))
		return TRUE
	var/line_start = findlasttext(before, "\n")
	return findtext(before, "//", line_start + 1) != 0

/// 1-based line number of `position` in `text`.
/proc/vc_jbs_line_number(text, position)
	return vc_test_count_occurrences(copytext(text, 1, position), "\n") + 1

/**
 * Every `<something>stat <op> STABLE` comparison in `text`, as a list of line numbers.
 */
/proc/vc_jbs_stat_comparisons(text)
	var/list/hits = list()
	var/position = findtext(text, "STABLE")
	while(position)
		var/next = position + length("STABLE")
		if(!vc_jbs_in_comment(text, position) && vc_jbs_is_stat_comparison(text, position))
			hits += vc_jbs_line_number(text, position)
		position = findtext(text, "STABLE", next)
	return hits

// ===========================================================================
// 1. The cryopod join seam
// ===========================================================================

/**
 * # A cryopod handed a TYPE PATH spawns a real mob and swallows it
 *
 * The prod round-16 break (13 runtimes, every ship, every roundstart crewmate).
 * `/datum/job/get_spawn_mob()` calls `spawn_point.JoinPlayerHere(spawn_type, TRUE)` with
 * a **typepath**; the upstream base instantiates it and returns the mob, and only the
 * return value is a mob at all. The fork's override used the argument, so `SetStun()` ran
 * on a path and `close_machine()` aborted before setting an occupant.
 *
 * The occupant assertion is the real detector: a version that returns the parent's mob
 * but still passes the raw argument to `close_machine()` leaves the pod empty and the
 * crewmate standing on the deck, which is what players actually saw.
 *
 * Coverage boundary: `get_spawn_mob()` cannot itself be driven — see the file header.
 * This drives the two layers below it, which is where the fork's code lives.
 */
/datum/unit_test/voidcrew_cryopod_join_contract

/datum/unit_test/voidcrew_cryopod_join_contract/Run()
	// Census first: if the fork grows a second JoinPlayerHere override, this table stops
	// being the whole story and the test must be extended rather than quietly narrowed.
	var/list/sources = list()
	vc_test_collect_dm_files(VC_JBS_FORK_ROOT, sources)
	TEST_ASSERT(length(sources) > 400, "the fork source scan found only [length(sources)] .dm files under [VC_JBS_FORK_ROOT] - wrong root?")
	var/override_count = vc_jbs_count_overrides(sources, "JoinPlayerHere")
	TEST_ASSERT_EQUAL(override_count, VC_JBS_JOINPLAYERHERE_OVERRIDES, "the fork now has [override_count] JoinPlayerHere overrides; this test covers [VC_JBS_JOINPLAYERHERE_OVERRIDES]. Cover the new one here.")

	var/list/spawned_mobs = list()

	// --- the fork's own override -------------------------------------------------
	var/obj/machinery/cryopod/pod = allocate(/obj/machinery/cryopod)
	var/pod_result = pod.JoinPlayerHere(/mob/living/carbon/human/consistent, TRUE)

	if(ispath(pod_result))
		TEST_FAIL("/obj/machinery/cryopod/JoinPlayerHere() returned the TYPE PATH it was handed ([pod_result]) instead of the mob the parent instantiated. This is the roundstart cryopod outage.")
	else if(!isliving(pod_result))
		TEST_FAIL("/obj/machinery/cryopod/JoinPlayerHere() returned [pod_result || "null"], which is not a living mob.")
	else
		var/mob/living/spawned = pod_result
		spawned_mobs += spawned
		if(!ishuman(spawned))
			TEST_FAIL("JoinPlayerHere(/mob/living/carbon/human/consistent) built a [spawned.type].")
		// The break detector. close_machine() has to be handed the mob the parent made,
		// not the argument, or the pod stays empty and the crewmate never boards.
		if(pod.occupant != spawned)
			TEST_FAIL("the cryopod did not take the spawned mob as its occupant (occupant is [pod.occupant || "null"]). close_machine() was not given a live mob.")
		if(spawned.loc != pod)
			TEST_FAIL("the spawned mob's loc is [spawned.loc || "null"], not the pod it joined at.")
		if(pod.state_open)
			TEST_FAIL("the cryopod is still open after taking a joiner.")
		if(pod.icon_state != pod.close_state)
			TEST_FAIL("the cryopod's icon_state is [pod.icon_state], not its close_state ([pod.close_state]) - the fork's close_machine() override did not run.")

	// --- the upstream implementations the same join path can land on ---------------
	// /atom base: the fallback every landmark and turf uses.
	var/turf_result = run_loc_floor_bottom_left.JoinPlayerHere(/mob/living/carbon/human/consistent, TRUE)
	if(!isliving(turf_result))
		TEST_FAIL("/atom/JoinPlayerHere() handed a typepath returned [turf_result || "null"] instead of instantiating it. The whole join path depends on this contract.")
	else
		var/mob/living/floor_mob = turf_result
		spawned_mobs += floor_mob
		if(floor_mob.loc != run_loc_floor_bottom_left)
			TEST_FAIL("/atom/JoinPlayerHere() left the mob at [floor_mob.loc || "null"] instead of the spawn point's turf.")

	// /obj/structure/chair: the buckling variant, used by SSjob.send_to_late_join().
	var/obj/structure/chair/seat = allocate(/obj/structure/chair, run_loc_floor_top_right)
	var/chair_result = seat.JoinPlayerHere(/mob/living/carbon/human/consistent, TRUE)
	if(!isliving(chair_result))
		TEST_FAIL("/obj/structure/chair/JoinPlayerHere() handed a typepath returned [chair_result || "null"] instead of a mob.")
	else
		var/mob/living/seated = chair_result
		spawned_mobs += seated
		if(seated.buckled != seat)
			TEST_FAIL("a chair given buckle = TRUE did not buckle the mob it spawned (buckled to [seated.buckled || "nothing"]).")

	// Not covered here: /obj/effect/landmark/start/hangover/JoinPlayerHere(). It is
	// upstream-owned and forwards the parent's return unchanged, but instantiating one
	// scatters beer-bottle debris across neighbouring turfs and registers the landmark
	// into GLOB.start_landmarks_list, i.e. it mutates round-global spawn state to test a
	// contract the /atom case above already covers.

	// --- the roundstart destination actually exists --------------------------------
	// A unit-test world loads every /datum/map_template/shuttle/voidcrew hull at boot
	// (SSovermap.spawn_initial_ship() has an #ifdef UNIT_TESTS branch), so mapped pods
	// exist and their spawn-point registration is assertable. A mapped pod is inspected
	// only, never occupied: sealing a mob into a live boot hull mutates world state that
	// later tests read.
	if(!length(SSovermap.simulated_ships))
		TEST_NOTICE(src, "no ships in this world, so the mapped-cryopod registration half of this test did not run")
	else
		var/obj/machinery/cryopod/mapped
		for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
			var/obj/docking_port/mobile/voidcrew/port = ship.shuttle
			if(isnull(port))
				continue
			// Filtered loop, not `as anything`: spawn_points is declared as a cryopod list
			// and only cryopods register, but if that ever stops being true this reports
			// "no pod registered" instead of runtiming on the first stranger in the list.
			for(var/obj/machinery/cryopod/candidate in port.spawn_points)
				mapped = candidate
				break
			if(mapped)
				break
		if(isnull(mapped))
			TEST_FAIL("[length(SSovermap.simulated_ships)] ships exist and not one has a cryopod registered in its spawn_points. A roundstart crewmate would have nowhere to arrive.")
		else
			TEST_ASSERT_NOTNULL(mapped.linked_ship, "a mapped cryopod is in a ship's spawn_points but its own linked_ship is null - the registration is one-way.")
			TEST_ASSERT(mapped in mapped.linked_ship.spawn_points, "a mapped cryopod's linked_ship does not list it as a spawn point.")

	for(var/mob/living/leftover as anything in spawned_mobs)
		qdel(leftover)

// ===========================================================================
// 2. The cryo departure wake guard
// ===========================================================================

/**
 * # A knocked-out player is not "awake" for the purposes of leaving the round
 *
 * `try_return_to_cryo()` refuses anyone who is not awake (despawn.dm:121, re-checked at
 * :149 and in finish_cryo_countdown() at :193). Before the upgrade that guard read
 * `stat != CONSCIOUS`; the mechanical rename to `stat != STABLE` kept crit and death and
 * dropped unconsciousness entirely, so a sleeping or sedated player could be walked into
 * a pod and taken out of the round past a balloon alert that says "you must be awake!".
 *
 * ## Why this is a predicate assertion and not a click
 *
 * `try_return_to_cryo()` opens with `if(!iscarbon(user) || !user.client) return`, and a
 * DM test cannot produce a `/client`. Every path below that line is therefore identical
 * for a clientless mob whether the guard is right or wrong, so driving the console would
 * assert nothing. What is asserted instead is the exact discrimination the rename lost —
 * for a healthy knocked-out human the shipped predicate is TRUE while the pre-fix
 * predicate is FALSE — plus the drive itself, which must at least not seal the pod.
 * A revert of the guard's *source* is caught by voidcrew_stat_comparison_lint below.
 */
/datum/unit_test/voidcrew_cryo_wake_guard

/datum/unit_test/voidcrew_cryo_wake_guard/Run()
	var/obj/machinery/cryopod/pod = allocate(/obj/machinery/cryopod)
	var/mob/living/carbon/human/consistent/sleeper = allocate(/mob/living/carbon/human/consistent)

	TEST_ASSERT_EQUAL(sleeper.stat, STABLE, "a freshly allocated consistent human is not STABLE, so this test cannot say anything about knockout.")
	TEST_ASSERT(!IS_UNCONSCIOUS_OR_CRIT(sleeper), "an awake, healthy human already reads as unconscious-or-crit; the guard would refuse everybody.")

	ADD_TRAIT(sleeper, TRAIT_KNOCKEDOUT, "voidcrew_join_bank_stat")

	// The silent half of the upgrade: being knocked out no longer moves `stat` at all.
	TEST_ASSERT_EQUAL(sleeper.stat, STABLE, "a knocked-out but healthy human should still read STABLE after tg #97041 - if this changed, the whole migration needs revisiting, not just this test.")
	TEST_ASSERT(IS_UNCONSCIOUS_OR_CRIT(sleeper), "IS_UNCONSCIOUS_OR_CRIT() is FALSE for a knocked-out human. The cryo wake guard, and 43 other migrated sites, are letting unconscious mobs through.")
	// The pre-fix predicate, spelled out. This is the comparison the rename produced and
	// the reason the outage was silent: it is FALSE exactly when the guard needed TRUE.
	TEST_ASSERT(!(sleeper.stat != STABLE), "the pre-fix `stat != STABLE` predicate is TRUE for a knocked-out mob, so this test is no longer demonstrating the break it was written for.")

	// The drive. Non-discriminating for a clientless mob (see the docstring) but it must
	// never seal the pod, and it must not runtime - the suite's zero-runtime verdict is
	// the assertion for the second half, there being no TEST_ASSERT_NO_RUNTIME.
	pod.try_return_to_cryo(sleeper)
	TEST_ASSERT_NULL(pod.occupant, "try_return_to_cryo() sealed a knocked-out mob into the pod.")
	TEST_ASSERT_NOTEQUAL(sleeper.loc, pod, "a knocked-out mob ended up inside the cryopod.")

	REMOVE_TRAIT(sleeper, TRAIT_KNOCKEDOUT, "voidcrew_join_bank_stat")
	TEST_ASSERT(!IS_UNCONSCIOUS_OR_CRIT(sleeper), "removing TRAIT_KNOCKEDOUT did not restore the mob to awake.")

// ===========================================================================
// 3. bank_cards is a lazylist
// ===========================================================================

/**
 * # Three cards on one account are three list entries
 *
 * `datum/bank_account.bank_cards` is a lazylist: null until the first card, and only
 * `/obj/item/card/id/set_account()` (which LAZYORs) may add to it. The fork's
 * `register_crewmember()` used `bank_cards += card`, and `null + object` in DM is the
 * object, so the first crewmate turned the list into a bare card; `LAZYLEN()` then reads
 * 0 and `bank_card_talk()` bails at its first line for the rest of the round. Every
 * payday, transfer, bounty payout and CRAB-17 notification for that ship went silent.
 */
/datum/unit_test/voidcrew_bank_card_lazylist

/datum/unit_test/voidcrew_bank_card_lazylist/Run()
	// account_job must be a real job datum: /datum/bank_account/Destroy() dereferences
	// account_job.type unconditionally.
	var/datum/job/job = SSjob.get_job_type(/datum/job/assistant)
	TEST_ASSERT_NOTNULL(job, "SSjob has no assistant job datum to hang a test account off.")
	var/datum/bank_account/account = allocate(/datum/bank_account, "Unit Test Account", job, 1, FALSE)

	TEST_ASSERT(!LAZYLEN(account.bank_cards), "a fresh bank account already has cards on it.")

	var/list/cards = list()
	for(var/index in 1 to 3)
		var/obj/item/card/id/card = allocate(/obj/item/card/id)
		cards += card
		card.set_account(account)

		// Asserted after EACH card: the broken `+=` produced a non-list on the first one
		// and a type mismatch on every one after, so a test that only checks the end
		// state cannot say which half failed.
		TEST_ASSERT(islist(account.bank_cards), "after card [index], bank_cards is a [account.bank_cards ? "[account.bank_cards]" : "null"] rather than a list. set_account() was bypassed by a bare += somewhere.")
		TEST_ASSERT_EQUAL(LAZYLEN(account.bank_cards), index, "after card [index], the account holds [LAZYLEN(account.bank_cards)] cards.")
		TEST_ASSERT(card in account.bank_cards, "card [index] set_account()'d onto the account but is not in bank_cards.")
		TEST_ASSERT_EQUAL(card.registered_account, account, "card [index] does not point back at the account it was registered to.")

	// bank_card_talk()'s only bail condition is `!LAZYLEN(bank_cards)`, so this is the
	// state that makes every ship notification live. The call itself has no observable
	// result without a client on the other end; it is made so that a runtime inside it
	// fails the run through the suite's zero-runtime verdict.
	TEST_ASSERT(LAZYLEN(account.bank_cards), "bank_card_talk() would bail immediately: the account has no cards.")
	account.bank_card_talk("unit test notification")

	// The lazylist has to shrink cleanly too, or a crewmate who dies and respawns
	// corrupts the ship's notification list from the other end.
	var/obj/item/card/id/first = cards[1]
	first.clear_account()
	TEST_ASSERT(islist(account.bank_cards), "clear_account() collapsed bank_cards out of list shape.")
	TEST_ASSERT_EQUAL(LAZYLEN(account.bank_cards), 2, "clear_account() left [LAZYLEN(account.bank_cards)] cards instead of 2.")
	TEST_ASSERT_NULL(first.registered_account, "clear_account() left the card pointing at the account.")

/**
 * # Two crewmates register onto one ship's account
 *
 * The integration half of the same incident, on the proc that shipped it. Two crew is the
 * minimum that reproduces: `bank_cards += card` on a null lazylist stores the first card
 * as a bare object, and only the *second* crewmate makes the corruption obvious, which is
 * why this shipped. The state is asserted after each registration.
 *
 * Uses the assembled-ship fixture rather than one of the boot hulls: register_crewmember()
 * mutates the ship's team, account and roster permanently, and a leaked or dirtied boot
 * hull outlives this test.
 */
/datum/unit_test/voidcrew_ship_crew_bank_registration
	priority = TEST_LONGER

/datum/unit_test/voidcrew_ship_crew_bank_registration/Run()
	var/obj/structure/overmap/ship/ship = vc_create_test_ship()
	if(isnull(ship))
		return // the fixture has already recorded why

	if(isnull(ship.ship_account) || isnull(ship.ship_team))
		TEST_FAIL("the fixture ship came up with [isnull(ship.ship_account) ? "no bank account" : "no crew team"]; register_crewmember() cannot be driven.")
		vc_release_test_ship(ship)
		return

	// register_crewmember() writes paycheck_department onto the mind's assigned_role,
	// which for a test mind is SSjob's shared /datum/job/unassigned singleton. Save and
	// restore it so this test does not leak a department name into the rest of the run.
	var/datum/job/unassigned = SSjob.get_job_type(/datum/job/unassigned)
	var/original_department = unassigned?.paycheck_department

	var/list/crew = list()
	var/list/cards = list()
	var/failed = FALSE

	for(var/index in 1 to 2)
		var/mob/living/carbon/human/consistent/crewmate = allocate(/mob/living/carbon/human/consistent)
		crewmate.mind_initialize()
		crew += crewmate

		var/obj/item/card/id/card = allocate(/obj/item/card/id)
		crewmate.equip_to_slot(card, ITEM_SLOT_ID)
		if(crewmate.wear_id != card)
			// Loud rather than vacuous: register_crewmember() returns early with no ID,
			// and a silent skip here would make every assertion below meaningless.
			TEST_FAIL("crewmate [index] would not wear the test ID, so register_crewmember() would return before touching any account.")
			failed = TRUE
			break
		cards += card

		// A personal account to be folded into the ship's, which is the branch that
		// actually calls set_account(). Without one, register_crewmember() skips the
		// whole account block and this test would pass on a broken tree.
		var/datum/bank_account/personal = new(newname = "Test Crew [index]", job = crewmate.mind.assigned_role, player_account = TRUE)
		crewmate.account_id = personal.account_id
		if(SSeconomy.bank_accounts_by_id["[crewmate.account_id]"] != personal)
			TEST_FAIL("the personal account for crewmate [index] did not register in SSeconomy.bank_accounts_by_id, so register_crewmember() will not find it.")
			qdel(personal)
			failed = TRUE
			break

		ship.register_crewmember(crewmate)

		TEST_ASSERT(islist(ship.ship_account.bank_cards), "after crewmate [index], the ship account's bank_cards is not a list. This is the fleet-wide notification outage: a bare `+=` on the lazylist.")
		TEST_ASSERT_EQUAL(LAZYLEN(ship.ship_account.bank_cards), index, "after crewmate [index], the ship account holds [LAZYLEN(ship.ship_account.bank_cards)] cards.")
		TEST_ASSERT(card in ship.ship_account.bank_cards, "crewmate [index]'s ID is not on the ship account's card list, so they will never hear a payday.")
		TEST_ASSERT_EQUAL(card.registered_account, ship.ship_account, "crewmate [index]'s ID still points at [card.registered_account || "nothing"] rather than the ship account.")
		TEST_ASSERT(QDELETED(personal), "crewmate [index]'s personal account survived registration; it should have been folded into the ship's.")
		TEST_ASSERT(crewmate.mind in ship.ship_team.members, "crewmate [index] is not on the ship's crew team.")

	if(!failed)
		TEST_ASSERT(LAZYLEN(ship.ship_account.bank_cards), "the ship account ends with no cards, so bank_card_talk() bails on every notification for this hull.")
		// See the lazylist test: no observable result, made so a runtime fails the run.
		ship.ship_account.bank_card_talk("unit test payday")

	if(!isnull(unassigned))
		unassigned.paycheck_department = original_department
	vc_release_test_ship(ship)

// ===========================================================================
// 4. Export appraisal
// ===========================================================================

/**
 * # A valuable item appraises as valuable
 *
 * `/datum/export/applies_to()`'s third parameter became a *list* of markets. The fork's
 * `item_export_value()` passed the bare `EXPORT_MARKET_STATION` string; `for(x in "supply")`
 * iterates zero times, so `applies_to()` fell off its loop returning null for every export
 * datum in the game and the appraisal was 0 for every item in the game. Nothing in the UI
 * distinguishes "worth nothing" from "the loop never ran", which is why it went unnoticed.
 */
/datum/unit_test/voidcrew_item_export_value

/datum/unit_test/voidcrew_item_export_value/Run()
	TEST_ASSERT(length(GLOB.exports_list), "GLOB.exports_list is empty, so no appraisal could work regardless of argument shape.")

	// An armour vest is covered by /datum/export/sec_armor at a flat cost with no
	// elasticity or material composition in the way, so its appraisal is a fixed number.
	var/obj/item/clothing/suit/armor/vest/vest = allocate(/obj/item/clothing/suit/armor/vest)

	var/value = item_export_value(vest)
	TEST_ASSERT(value > 0, "item_export_value() appraised [vest.type] at [value]. Cargo pays for this item, so a zero here means applies_to() matched nothing - check that the export market argument is still a list.")

	// The proc can and does return 0, so the assertion above is not trivially true.
	TEST_ASSERT_EQUAL(item_export_value(null), 0, "item_export_value(null) did not return 0; its istype() guard is gone.")

	// The contract itself, at the call the fork makes: a LIST of markets. Passing the
	// bare string here is what broke, and is deliberately not re-tested by calling it —
	// this pins the working shape so a future edit has something to compare against.
	var/datum/export/matched
	for(var/datum/export/candidate as anything in GLOB.exports_list)
		if(candidate.applies_to(vest, FALSE, list(EXPORT_MARKET_STATION)))
			matched = candidate
			break
	TEST_ASSERT_NOTNULL(matched, "no export datum in GLOB.exports_list applies to [vest.type] when applies_to() is given a proper list of markets.")
	TEST_ASSERT(matched.get_cost(vest, FALSE) > 0, "[matched.type] applies to [vest.type] but prices it at zero.")

	// The player-facing symptom of the outage: "nobody's buying" about everything.
	TEST_ASSERT(item_trade_value_score(vest) > 0, "item_trade_value_score() scored [vest.type] at zero despite a live export price.")
	TEST_ASSERT_NOTNULL(item_trade_value_text(vest), "item_trade_value_text() had nothing to say about an item cargo pays for - this is the Fence's Eye reading 'nobody's buying'.")

// ===========================================================================
// 5. The stat enum contract
// ===========================================================================

/**
 * # The mob health stat enum is exactly STABLE / SOFT_CRIT / HARD_CRIT / DEAD
 *
 * tg #97041 (7357a3441ff) renamed CONSCIOUS to STABLE and **deleted UNCONSCIOUS**,
 * moving "out cold" onto TRAIT_KNOCKEDOUT. Two shapes of fork breakage followed: a
 * `stat != CONSCIOUS` renamed to `stat != STABLE` silently stopped covering knockout, and
 * an `UNCONSCIOUS` swapped for `HARD_CRIT` because the two shared the enum value 2.
 *
 * This pins the enum itself so the next upstream move to it fails here, loudly, instead
 * of silently changing the meaning of 44 migrated call sites. The source scan is what
 * makes "exactly" assertable: DM cannot enumerate its own defines.
 */
/datum/unit_test/voidcrew_stat_enum_contract

/datum/unit_test/voidcrew_stat_enum_contract/Run()
	// --- compiled values ------------------------------------------------------------
	TEST_ASSERT_EQUAL(STABLE, 0, "STABLE is no longer 0.")
	TEST_ASSERT_EQUAL(SOFT_CRIT, 1, "SOFT_CRIT is no longer 1.")
	TEST_ASSERT_EQUAL(HARD_CRIT, 2, "HARD_CRIT is no longer 2.")
	TEST_ASSERT_EQUAL(DEAD, 3, "DEAD is no longer 3.")

	// --- declared set -----------------------------------------------------------------
	var/text = file2text(VC_JBS_STAT_DEFINES)
	TEST_ASSERT_NOTNULL(text, "could not read [VC_JBS_STAT_DEFINES].")
	var/marker = findtext(text, "//Maximum healthiness")
	TEST_ASSERT(marker, "[VC_JBS_STAT_DEFINES] no longer contains the '//Maximum healthiness' line this scan uses to find the end of the health-stat block. Re-anchor the scan; do not delete it.")

	var/list/declared = list()
	for(var/line in splittext(copytext(text, 1, marker), "\n"))
		line = trim(line)
		if(copytext(line, 1, 9) != "#define ")
			continue
		var/list/parts = splittext(line, " ")
		if(length(parts) < 3)
			continue
		declared[parts[2]] = text2num(parts[3])

	var/list/expected = list("STABLE" = STABLE, "SOFT_CRIT" = SOFT_CRIT, "HARD_CRIT" = HARD_CRIT, "DEAD" = DEAD)
	TEST_ASSERT_EQUAL(length(declared), length(expected), "the mob health stat block declares [length(declared)] values ([declared.Join(", ")]), not the [length(expected)] this fork's 44 migrated stat checks were written against.")
	for(var/name in expected)
		TEST_ASSERT(name in declared, "the stat enum no longer declares [name].")
		TEST_ASSERT_EQUAL(declared[name], expected[name], "[name] is declared as [declared[name]] in source but compiles to [expected[name]].")
	// The two names whose removal caused the outage. If either comes back, every
	// migrated IS_UNCONSCIOUS_OR_CRIT() site needs re-reading, not a quiet re-rename.
	TEST_ASSERT(!findtext(text, "#define UNCONSCIOUS"), "UNCONSCIOUS is a stat value again. Re-read the 44 sites migrated off it before touching this assertion.")
	TEST_ASSERT(!findtext(text, "#define CONSCIOUS"), "CONSCIOUS is a stat value again. Re-read the 44 sites migrated off it before touching this assertion.")

	// --- the helper macros' semantics -------------------------------------------------
	var/mob/living/carbon/human/consistent/subject = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_EQUAL(subject.stat, STABLE, "a healthy consistent human is not STABLE.")
	TEST_ASSERT(!IS_UNCONSCIOUS(subject), "an awake human reads as unconscious.")
	TEST_ASSERT(!IS_UNCONSCIOUS_OR_CRIT(subject), "an awake, healthy human reads as unconscious-or-crit.")

	ADD_TRAIT(subject, TRAIT_KNOCKEDOUT, "voidcrew_join_bank_stat")
	// The whole point of the migration: knocked out at STABLE.
	TEST_ASSERT_EQUAL(subject.stat, STABLE, "TRAIT_KNOCKEDOUT moved the mob's stat. If knockout is health-derived again, the migration table changes.")
	TEST_ASSERT(IS_UNCONSCIOUS(subject), "IS_UNCONSCIOUS() is FALSE for a mob with TRAIT_KNOCKEDOUT.")
	TEST_ASSERT(IS_UNCONSCIOUS_OR_CRIT(subject), "IS_UNCONSCIOUS_OR_CRIT() is FALSE for a knocked-out mob - this is the predicate 44 fork sites depend on.")
	TEST_ASSERT(IS_UNCONSCIOUS_AND_ALIVE(subject), "IS_UNCONSCIOUS_AND_ALIVE() is FALSE for a knocked-out living mob.")
	REMOVE_TRAIT(subject, TRAIT_KNOCKEDOUT, "voidcrew_join_bank_stat")

	// The crit half, which the mechanical rename did keep. Asserted so a future change
	// that fixes knockout by breaking crit cannot pass.
	subject.set_stat(SOFT_CRIT)
	TEST_ASSERT(IS_UNCONSCIOUS_OR_CRIT(subject), "IS_UNCONSCIOUS_OR_CRIT() is FALSE for a mob in soft crit.")
	TEST_ASSERT(!IS_UNCONSCIOUS(subject), "a mob in soft crit with no TRAIT_KNOCKEDOUT reads as unconscious.")
	subject.set_stat(STABLE)
	TEST_ASSERT(!IS_UNCONSCIOUS_OR_CRIT(subject), "restoring STABLE did not clear the unconscious-or-crit reading.")

/**
 * # No fork code compares a stat against STABLE outside the allowlist
 *
 * The lint half of the same incident, and the only guard that catches a *revert*. Every
 * `stat != CONSCIOUS` in the fork became `stat != STABLE` on the merge, which compiles,
 * reads correctly and quietly stops covering unconscious mobs. 44 of them were migrated
 * to IS_UNCONSCIOUS_OR_CRIT(); this fails if any comes back.
 *
 * Three comparisons are deliberately kept, all in ware_military_body.dm: two COMSIG
 * handlers that receive a **raw stat value** rather than a mob (so the IS_UNCONSCIOUS_*
 * macros do not apply) and one genuine health-semantics check. The allowlist asserts its
 * own match count as well as its file, so a rename or a deletion that stops the scan
 * matching fails here instead of turning the whole lint vacuous.
 */
/datum/unit_test/voidcrew_stat_comparison_lint
	priority = TEST_LONGER

/datum/unit_test/voidcrew_stat_comparison_lint/Run()
	var/list/sources = list()
	vc_test_collect_dm_files(VC_JBS_FORK_ROOT, sources)
	TEST_ASSERT(length(sources) > 400, "the fork source scan found only [length(sources)] .dm files under [VC_JBS_FORK_ROOT] - wrong root?")

	var/allowlisted = 0
	for(var/path in sources)
		var/text = sources[path]
		// Cheap prefilter: only a handful of fork files mention STABLE at all.
		if(!findtext(text, "STABLE"))
			continue
		var/list/hits = vc_jbs_stat_comparisons(text)
		if(!length(hits))
			continue
		if(path == VC_JBS_STAT_ALLOWLIST_FILE)
			allowlisted = length(hits)
			continue
		for(var/line in hits)
			TEST_FAIL("[path]:[line] compares a stat against STABLE. That predicate lost the unconscious half when upstream deleted the UNCONSCIOUS stat (tg #97041): use IS_UNCONSCIOUS_OR_CRIT(mob), or IS_UNCONSCIOUS(mob) if only knockout is meant.")

	TEST_ASSERT_EQUAL(allowlisted, VC_JBS_STAT_ALLOWLIST_COUNT, "[VC_JBS_STAT_ALLOWLIST_FILE] holds [allowlisted] stat-vs-STABLE comparisons, not the [VC_JBS_STAT_ALLOWLIST_COUNT] this lint is allowed to ignore. If the file changed on purpose, re-read each site (they are raw COMSIG stat values, not mobs) and update the count; do not widen the allowlist to make this pass.")

// ===========================================================================
// 6. Migrated guards, driven
// ===========================================================================

/**
 * # Two migrated guards refuse a knocked-out but healthy human
 *
 * The behavioural sample of the 44-site migration. Most of those sites are inside AI
 * subtrees, do_after channels or item attack chains that need a live ruin, a pact datum
 * or a client to reach, so two were picked for being genuine predicates callable
 * directly:
 *
 * - `can_be_lich_thralled()` (lich/lich_thrall.dm:100) — a global proc, and the exact
 *   "never someone out cold" rule the comment on it claims.
 * - `/datum/action/cooldown/spell/vestige_devour/gullet_menu_check()`
 *   (antag_ruins/theme_morph.dm:1368) — the vestige boon's radial-menu validity check.
 *
 * Both were `stat != STABLE` after the merge, i.e. both said "yes, thrall them / yes,
 * open the menu" for an unconscious player. The remaining 42 sites are held by
 * voidcrew_stat_comparison_lint (a revert fails there) and by the enum contract above.
 */
/datum/unit_test/voidcrew_knockout_guard_behaviour

/datum/unit_test/voidcrew_knockout_guard_behaviour/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)

	TEST_ASSERT(can_be_lich_thralled(victim), "an awake, healthy human cannot be lich-thralled, so this test cannot show the guard discriminating.")

	// Target passed the way spell_jaunt.dm does it, so the action links to a real datum
	// rather than taking /datum/action/New()'s null-target path.
	var/datum/action/cooldown/spell/vestige_devour/gullet = allocate(/datum/action/cooldown/spell/vestige_devour, victim)
	gullet.Grant(victim)
	TEST_ASSERT_EQUAL(gullet.owner, victim, "the gullet spell would not attach to the test human.")
	TEST_ASSERT(gullet.gullet_menu_check(), "the gullet's menu check refuses an awake, healthy owner.")

	ADD_TRAIT(victim, TRAIT_KNOCKEDOUT, "voidcrew_join_bank_stat")
	TEST_ASSERT_EQUAL(victim.stat, STABLE, "the knocked-out human is not at STABLE, so these guards are being tested against crit rather than knockout.")

	TEST_ASSERT(!can_be_lich_thralled(victim), "can_be_lich_thralled() accepts a knocked-out target. The lich can thrall unconscious players, which the guard exists to prevent.")
	TEST_ASSERT(!gullet.gullet_menu_check(), "the gullet's menu check accepts a knocked-out owner.")

	REMOVE_TRAIT(victim, TRAIT_KNOCKEDOUT, "voidcrew_join_bank_stat")
	TEST_ASSERT(can_be_lich_thralled(victim), "waking the target back up did not restore it as a thrall candidate; the guard is stuck rather than discriminating.")

	gullet.Remove(victim)

// ===========================================================================
// 7. close_machine() null tolerance
// ===========================================================================

/**
 * # Every fork close_machine() override survives a null target
 *
 * `/obj/machinery/close_machine(atom/movable/target, ...)` accepts a null target and then
 * scans its own turf for an occupant — that is how every "shove someone in and shut it"
 * path and every empty close works. The cryopod override learned this the hard way on the
 * upgrade (it was reached with a non-mob and aborted mid-way, leaving the pod
 * half-closed), so all five fork overrides are swept here.
 *
 * There is no TEST_ASSERT_NO_RUNTIME: the claim "none of these runtimes on a null target"
 * is carried by the suite's own zero-runtime verdict, which refuses to write clean_run.lk
 * if any of these calls raises. The state assertions are what this file can check
 * directly.
 *
 * Machines are allocated on the far corner turf, deliberately with no mob standing on it:
 * with a null target the parent adopts whatever occupant candidate is on its tile, and
 * this test is about the null path, not the adoption path.
 */
/datum/unit_test/voidcrew_close_machine_null_target
	priority = TEST_LONGER

/datum/unit_test/voidcrew_close_machine_null_target/Run()
	var/list/sources = list()
	vc_test_collect_dm_files(VC_JBS_FORK_ROOT, sources)
	var/override_count = vc_jbs_count_overrides(sources, "close_machine")
	TEST_ASSERT_EQUAL(override_count, VC_JBS_CLOSE_MACHINE_OVERRIDES, "the fork now has [override_count] close_machine overrides; this sweep covers [VC_JBS_CLOSE_MACHINE_OVERRIDES]. Add the new one to the list below.")

	var/static/list/sweep = list(
		/obj/machinery/cryopod,
		/obj/machinery/nanite_chamber,
		/obj/machinery/blueprint_imprinter,
		/obj/machinery/modsuit_bench,
		// Last on purpose: its close arms a 3-second injection timer, and the sleep that
		// lets that timer land is at the end of this proc.
		/obj/machinery/public_nanite_chamber,
	)

	for(var/machine_type in sweep)
		var/obj/machinery/machine = allocate(machine_type, run_loc_floor_top_right)
		// The nanite chambers refuse to close when they are already closed, so an
		// already-shut machine would take the guard branch and never reach the parent.
		machine.open_machine()
		TEST_ASSERT(machine.state_open, "[machine_type] would not open, so its close_machine() override cannot be exercised.")

		machine.close_machine(null)

		TEST_ASSERT(!machine.state_open, "[machine_type].close_machine(null) left the machine open.")
		TEST_ASSERT_NULL(machine.occupant, "[machine_type].close_machine(null) invented an occupant ([machine.occupant]) on an empty tile.")

	// /obj/machinery/public_nanite_chamber/close_machine() schedules try_inject_nanites()
	// three seconds out. Waiting for it here means it fires against a live machine with a
	// null occupant (a no-op) instead of against one the runner has already qdel'd, which
	// is the shape that produces SSTimer's null.type runtimes.
	sleep(3.5 SECONDS)

// ===========================================================================
// 8. early_melee_attack() return contract
// ===========================================================================

/**
 * # Fork early_melee_attack() overrides return BASIC_MOB_* codes with the right polarity
 *
 * `/mob/living/basic/melee_attack()` reads **any truthy return** from
 * `early_melee_attack()` as "stop the chain", and BASIC_MOB_CONTINUE_ATTACK_CHAIN is 0.
 * So an override that returns bare FALSE to mean "do not attack" swings anyway. Four fork
 * overrides had that inversion; the Vestige Mimic's is the one players saw, attacking
 * from inside its disguise and never breaking form.
 *
 * ## What can and cannot be asserted
 *
 * DM has no way to tell `TRUE` from `BASIC_MOB_END_ATTACK_CHAIN` — both are 1 — so
 * "returns a constant, never a bare boolean" is not directly checkable. What is checkable,
 * and is what actually broke, is the **polarity at both ends**: the blocking state must
 * return a truthy BASIC_MOB_* code and the free state must return exactly
 * BASIC_MOB_CONTINUE_ATTACK_CHAIN (0). A bare FALSE in the blocking branch fails the first;
 * a bare TRUE in the free branch fails the second. Every return is also checked for
 * membership in the BASIC_MOB_* value set, which catches a stray return of some unrelated
 * truthy value such as a mob or a string.
 */
/datum/unit_test/voidcrew_early_melee_attack_contract

/datum/unit_test/voidcrew_early_melee_attack_contract/Run()
	var/list/sources = list()
	vc_test_collect_dm_files(VC_JBS_FORK_ROOT, sources)
	var/override_count = vc_jbs_count_overrides(sources, "early_melee_attack")
	TEST_ASSERT_EQUAL(override_count, VC_JBS_EARLY_MELEE_OVERRIDES, "the fork now has [override_count] early_melee_attack overrides; this sweep covers [VC_JBS_EARLY_MELEE_OVERRIDES]. Add the new one below - a bare boolean return there is a silent attack-polarity inversion.")

	var/list/valid_returns = list(BASIC_MOB_CONTINUE_ATTACK_CHAIN, BASIC_MOB_END_ATTACK_CHAIN, BASIC_MOB_END_ATTACK_CHAIN_COOLDOWN)
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)

	// --- the three "locked state" bosses ---------------------------------------------
	// Each one is immobile and committed to something while its state var is set, and
	// each returned bare FALSE there before the fix, i.e. it swung anyway.
	var/mob/living/basic/vestige_warframe/warframe = allocate(/mob/living/basic/vestige_warframe)
	warframe.set_committed(TRUE)
	check_early_melee(warframe, target, BASIC_MOB_END_ATTACK_CHAIN, "committed to a move", valid_returns)
	warframe.set_committed(FALSE)
	check_early_melee(warframe, target, BASIC_MOB_CONTINUE_ATTACK_CHAIN, "free to swing", valid_returns)

	var/mob/living/basic/vestige_oracle/oracle = allocate(/mob/living/basic/vestige_oracle)
	oracle.set_inert(TRUE)
	check_early_melee(oracle, target, BASIC_MOB_END_ATTACK_CHAIN, "planted", valid_returns)
	oracle.set_inert(FALSE)
	check_early_melee(oracle, target, BASIC_MOB_CONTINUE_ATTACK_CHAIN, "free to swing", valid_returns)

	var/mob/living/basic/hoarfrost_matriarch/matriarch = allocate(/mob/living/basic/hoarfrost_matriarch)
	matriarch.set_inert(TRUE)
	check_early_melee(matriarch, target, BASIC_MOB_END_ATTACK_CHAIN, "planted", valid_returns)
	matriarch.set_inert(FALSE)
	check_early_melee(matriarch, target, BASIC_MOB_CONTINUE_ATTACK_CHAIN, "free to swing", valid_returns)

	// --- the Mimic ------------------------------------------------------------------
	// Its whole design is that attacking breaks the disguise and the swing never lands,
	// so its override ends the chain unconditionally and queues the break. Returning
	// FALSE (which is what shipped) landed the hit and kept the form.
	var/mob/living/basic/vestige_mimic/mimic = allocate(/mob/living/basic/vestige_mimic)
	check_early_melee(mimic, target, BASIC_MOB_END_ATTACK_CHAIN, "attacking from inside its disguise", valid_returns)
	TEST_ASSERT(mimic.breaking, "the Mimic attacked without queueing its form break. It is fighting as furniture, which is exactly the state its design forbids.")

	// The queued break is a one-decisecond timer; let it land against the live mob rather
	// than against one the runner has already qdel'd.
	sleep(0.5 SECONDS)

/// Shared assertion body for the sweep above.
/datum/unit_test/voidcrew_early_melee_attack_contract/proc/check_early_melee(mob/living/basic/attacker, atom/target, expected, state, list/valid_returns)
	var/result = attacker.early_melee_attack(target, null, TRUE)
	if(!(result in valid_returns))
		TEST_FAIL("[attacker.type].early_melee_attack() returned [isnull(result) ? "null" : result] while [state], which is not a BASIC_MOB_* attack-chain code.")
		return
	if(result != expected)
		var/diagnosis = expected == BASIC_MOB_CONTINUE_ATTACK_CHAIN \
			? "it should have let the chain continue (BASIC_MOB_CONTINUE_ATTACK_CHAIN, 0) and instead stopped it" \
			: "it should have ended the chain and instead returned [result] - BASIC_MOB_CONTINUE_ATTACK_CHAIN is 0, so a bare FALSE here means 'swing anyway'"
		TEST_FAIL("[attacker.type].early_melee_attack() returned [result] while [state]: [diagnosis].")

#undef VC_JBS_FORK_ROOT
#undef VC_JBS_STAT_DEFINES
#undef VC_JBS_STAT_ALLOWLIST_FILE
#undef VC_JBS_STAT_ALLOWLIST_COUNT
#undef VC_JBS_JOINPLAYERHERE_OVERRIDES
#undef VC_JBS_CLOSE_MACHINE_OVERRIDES
#undef VC_JBS_EARLY_MELEE_OVERRIDES
