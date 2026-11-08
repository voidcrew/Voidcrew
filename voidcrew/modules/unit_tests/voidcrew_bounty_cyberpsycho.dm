/**
 * The cyberpsycho (voidcrew/modules/bounties/chrome/bounty_cyberpsycho.dm): its posting, its spawn, the
 * order its chrome works in, EMP, capture, clean-up, and a render of its look. Every test drives the
 * procs directly with the mobs in place (a test world has no clients, so the AI is off); the pieces'
 * wind-ups are called with their serials rather than waited for. Fork defines are included after the
 * tests, so a test uses the literal value with a comment naming the define. The test room is 5x5.
 */
/datum/unit_test/voidcrew_bounty_cyberpsycho
	abstract_type = /datum/unit_test/voidcrew_bounty_cyberpsycho

/// The floor tile `dx`, `dy` from the room's bottom left
/datum/unit_test/voidcrew_bounty_cyberpsycho/proc/tile(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A hunter at `where`: a human with a mind, as a player would be
/datum/unit_test/voidcrew_bounty_cyberpsycho/proc/hunter_at(turf/where)
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, where)
	hunter.mind_initialize()
	return hunter

/// A cyberpsycho at `where`, hostile toward `hunter` (on its grudge list, so in its posse), with `hunter` as its target
/datum/unit_test/voidcrew_bounty_cyberpsycho/proc/psycho_at(turf/where, mob/living/hunter)
	var/mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho = allocate(/mob/living/basic/bounty_criminal/boss/cyberpsycho, where)
	if(hunter)
		psycho.body_add_grudge(hunter)
		psycho.boss_turn_hostile(hunter)
		psycho.ai_controller?.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)
	return psycho

/// Every cooldown of `psycho` and its pieces over, and no gap before its next move
/datum/unit_test/voidcrew_bounty_cyberpsycho/proc/ready(mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho)
	psycho.boss_next_ability_at = 0
	var/datum/bounty_chrome/cascade/cascade = psycho.psycho_piece("cascade")
	cascade.next_surge_at = 0
	var/datum/bounty_chrome/mantis/mantis = psycho.psycho_piece("mantis")
	mantis.next_lunge_at = 0
	var/datum/bounty_chrome/gorilla/gorilla = psycho.psycho_piece("gorilla")
	gorilla.punch_ready_at = 0
	var/datum/bounty_chrome/piledriver/piledriver = psycho.psycho_piece("piledriver")
	piledriver.next_leap_at = 0

/// The move of `move_type` that `psycho` has
/datum/unit_test/voidcrew_bounty_cyberpsycho/proc/move_of(mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho, move_type)
	return locate(move_type) in psycho.boss_abilities

/// Whether `psycho` is in the middle of any move: a punch, a lunge, a leap or a surge's spin-up
/datum/unit_test/voidcrew_bounty_cyberpsycho/proc/moves_running(mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho)
	var/datum/bounty_chrome/cascade/cascade = psycho.psycho_piece("cascade")
	var/datum/bounty_chrome/mantis/mantis = psycho.psycho_piece("mantis")
	var/datum/bounty_chrome/gorilla/gorilla = psycho.psycho_piece("gorilla")
	var/datum/bounty_chrome/piledriver/piledriver = psycho.psycho_piece("piledriver")
	. = 0
	if(cascade.phase == 1) // BOUNTY_CASCADE_SPINUP
		.++
	if(mantis.lunge_state)
		.++
	if(gorilla.busy)
		.++
	if(piledriver.phase)
		.++

/// Whether examining `who` shows a line with `text`
/datum/unit_test/voidcrew_bounty_cyberpsycho/proc/examine_has(mob/living/who, text)
	for(var/line in who.examine(who))
		if(findtext(line, text))
			return TRUE
	return FALSE

// ===== WHERE IT SITS =====

/**
 * The board: its rules (never early, twice a round at most, far apart, one at a time), an admin's
 * forced one, and the posting it makes: the record, the pay, the card and the warrant. Then it
 * spawns as the cyberpsycho with all seven pieces, and the Bounty Panel spawns one too.
 */
/datum/unit_test/voidcrew_bounty_cyberpsycho/posting
	var/saved_posted
	var/saved_last
	var/saved_forced

/datum/unit_test/voidcrew_bounty_cyberpsycho/posting/Run()
	saved_posted = GLOB.bounty_psycho_posted
	saved_last = GLOB.bounty_psycho_last_posted
	saved_forced = GLOB.bounty_psycho_forced
	board_test_begin()
	checks()
	board_test_end()
	GLOB.bounty_psycho_posted = saved_posted
	GLOB.bounty_psycho_last_posted = saved_last
	GLOB.bounty_psycho_forced = saved_forced

/datum/unit_test/voidcrew_bounty_cyberpsycho/posting/proc/checks()
	// The rules
	GLOB.bounty_psycho_posted = 0
	GLOB.bounty_psycho_last_posted = 0
	TEST_ASSERT_NOTNULL(bounty_psycho_post_refusal(30 MINUTES), "A cyberpsycho may go up half an hour in") // BOUNTY_PSYCHO_EARLIEST
	TEST_ASSERT_NULL(bounty_psycho_post_refusal(61 MINUTES), "A cyberpsycho may not go up an hour in")
	GLOB.bounty_psycho_posted = 1
	GLOB.bounty_psycho_last_posted = world.time
	TEST_ASSERT_NOTNULL(bounty_psycho_post_refusal(4 HOURS), "A second cyberpsycho may go up right after the first") // BOUNTY_PSYCHO_GAP
	GLOB.bounty_psycho_last_posted = world.time - 91 MINUTES
	TEST_ASSERT_NULL(bounty_psycho_post_refusal(4 HOURS), "A second cyberpsycho may not go up long after the first")
	GLOB.bounty_psycho_posted = 2 // BOUNTY_PSYCHO_PER_ROUND
	TEST_ASSERT_NOTNULL(bounty_psycho_post_refusal(4 HOURS), "A third cyberpsycho may go up in a round")
	GLOB.bounty_psycho_posted = 0

	// Only a public Most Wanted mini-boss, and only when the rules allow (a test runs minutes into its round)
	var/datum/bounty_record/record = generate_bounty_record(3, "boss", "planet") // BOUNTY_TIER_MOST_WANTED, BOUNTY_ARCHETYPE_BOSS
	for(var/i in 1 to 20)
		TEST_ASSERT_EQUAL(bounty_psycho_posting_type(record, "planet", null), /datum/criminal_bounty, "A cyberpsycho went up minutes into the round")
	TEST_ASSERT(record.kit != "cyberpsycho", "A record turned cyberpsycho without being posted as one") // BOUNTY_KIT_CYBERPSYCHO
	var/datum/bounty_record/wanted = generate_bounty_record(2, "normal", "planet")
	GLOB.bounty_psycho_forced = TRUE
	TEST_ASSERT_EQUAL(bounty_psycho_posting_type(wanted, "planet", null), /datum/criminal_bounty, "A forced Wanted posting became a cyberpsycho")
	TEST_ASSERT(!GLOB.bounty_psycho_forced, "The admin's forced cyberpsycho wasn't used up")
	GLOB.bounty_psycho_forced = TRUE
	TEST_ASSERT_EQUAL(bounty_psycho_posting_type(record, "trader_outpost", null), /datum/criminal_bounty, "A cyberpsycho went up at a trader outpost")

	// An admin's: the board posts it at a ruin
	var/obj/structure/overmap/space_ruin/ruin = allocate(/obj/structure/overmap/space_ruin, outpost_lead_overmap_turf(48, 48))
	GLOB.bounty_psycho_forced = TRUE
	var/datum/criminal_bounty/cyberpsycho/posting = post_criminal_bounty(3, "ruin", ruin)
	TEST_ASSERT(!GLOB.bounty_psycho_forced, "The forced cyberpsycho wasn't used up by the posting")
	TEST_ASSERT(istype(posting, /datum/criminal_bounty/cyberpsycho), "The forced Most Wanted isn't a cyberpsycho: [posting?.type]")
	if(!istype(posting))
		return
	TEST_ASSERT_EQUAL(GLOB.bounty_psycho_posted, 1, "The posting wasn't counted")
	TEST_ASSERT_EQUAL(bounty_psycho_open_posting(), posting, "The open cyberpsycho posting can't be found")
	TEST_ASSERT_NOTNULL(bounty_psycho_post_refusal(4 HOURS), "A second cyberpsycho may go up while one is on the board")
	var/datum/bounty_record/psycho_record = posting.record
	TEST_ASSERT_EQUAL(psycho_record.kit, "cyberpsycho", "The posted record's kit is [psycho_record.kit]")
	TEST_ASSERT_EQUAL(length(psycho_record.chrome), 7, "The posted record carries [length(psycho_record.chrome)] pieces of chrome")
	TEST_ASSERT(psycho_record.crime in bounty_psycho_crimes(), "The posted record is wanted for [psycho_record.crime]")
	// BOUNTY_PAY_MOST_WANTED_MIN 3000, _MAX 3800, times BOUNTY_PSYCHO_PAY_MULT 1.25
	TEST_ASSERT(psycho_record.base_value >= 3750 && psycho_record.base_value <= 4750, "The cyberpsycho's base value is [psycho_record.base_value]")
	TEST_ASSERT_EQUAL(posting.board_terms(), "Wanted dead or alive", "The card doesn't say dead or alive")
	// BOUNTY_SHARE_RESTRAINED 100, BOUNTY_SHARE_DOWNED 60
	TEST_ASSERT_EQUAL(posting.board_share_for("restrained", "stunned"), 100, "Cuffed on its feet, it doesn't pay in full")
	TEST_ASSERT_EQUAL(posting.board_share_for("restrained", "downed"), 60, "Cuffed after a downing, it doesn't pay the downed share")
	TEST_ASSERT_EQUAL(posting.board_share_for("dead", "dead"), 60, "Dead, it doesn't pay the downed share")
	TEST_ASSERT_EQUAL(posting.board_share_for("free", "free"), 0, "Free and standing, it pays")
	var/warrant = posting.board_warrant_text()
	TEST_ASSERT(findtext(warrant, "Wanted dead or alive</b>. Armed with military chrome."), "The warrant doesn't warn of the chrome")

	// It spawns as the cyberpsycho, with all of it
	var/mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho = spawn_bounty_criminal(posting.record, tile(2, 2), posting)
	if(psycho)
		allocated += psycho
	TEST_ASSERT(istype(psycho), "The posted cyberpsycho spawned as [psycho?.type]")
	if(!istype(psycho))
		return
	var/datum/component/bounty_chrome/chrome = psycho.GetComponent(/datum/component/bounty_chrome)
	TEST_ASSERT_EQUAL(length(chrome?.pieces), 7, "The cyberpsycho carries [length(chrome?.pieces)] pieces of chrome")
	var/list/expected = list(
		"cascade" = /datum/bounty_chrome/cascade/psycho,
		"mantis" = /datum/bounty_chrome/mantis/psycho,
		"gorilla" = /datum/bounty_chrome/gorilla/psycho,
		"redline" = /datum/bounty_chrome/redline/psycho,
		"piledriver" = /datum/bounty_chrome/piledriver/psycho,
		"lazarus" = /datum/bounty_chrome/lazarus,
		"deadeye" = /datum/bounty_chrome/deadeye/psycho,
	)
	for(var/key in expected)
		var/datum/bounty_chrome/piece = psycho.psycho_piece(key)
		TEST_ASSERT_EQUAL(piece?.type, expected[key], "Its [key] is a [piece?.type]")
		TEST_ASSERT_EQUAL(piece?.key, key, "Its [key] doesn't know its key")
		TEST_ASSERT_EQUAL(piece?.owner, psycho, "Its [key] isn't in it")
	// None of its pieces is a prototype the board could roll
	for(var/proto_key in GLOB.bounty_chrome_protos)
		var/datum/bounty_chrome/proto = GLOB.bounty_chrome_protos[proto_key]
		TEST_ASSERT(!findtext("[proto.type]", "/psycho"), "The psycho's [proto.type] is a prototype")
	TEST_ASSERT(findtext(jointext(bounty_chrome_scan_readout(psycho), " "), "SIGNATURES 7"), "A chrome read doesn't count seven pieces")
	for(var/text in list("right forearm", "left arm is plated", "neck", "speaker grille", "launch pistons", "ribs", "milspec optics"))
		TEST_ASSERT(examine_has(psycho, text), "Examining the cyberpsycho doesn't show \"[text]\"")
	TEST_ASSERT_EQUAL(jointext(psycho.boss_health_table(), ","), "300,900,1500,2100", "The cyberpsycho's health table changed") // BOUNTY_PSYCHO_HEALTH_*
	posting.close("admin") // BOUNTY_CLOSE_ADMIN

	// The Bounty Panel: listed with the kits, and a spawn at the admin's feet carries all of it whatever chrome was picked
	var/mob/living/carbon/human/operator = allocate(/mob/living/carbon/human/consistent, tile(4, 4))
	var/datum/bounty_admin_panel/unit_test/panel = allocate(/datum/bounty_admin_panel/unit_test, operator)
	var/list/kits = panel.kit_choices()
	TEST_ASSERT_EQUAL(kits["Cyberpsycho"], "cyberpsycho", "The Bounty Panel doesn't offer the cyberpsycho")
	var/mob/living/basic/bounty_criminal/boss/cyberpsycho/spawned = panel.admin_spawn_criminal(operator, 3, "boss", "cyberpsycho", null, tile(3, 3), list())
	if(spawned)
		allocated += spawned
	TEST_ASSERT(istype(spawned), "The Bounty Panel spawned [spawned?.type]: [panel.error]")
	TEST_ASSERT_EQUAL(get_turf(spawned), tile(3, 3), "The panel's cyberpsycho spawned away from the spot")
	TEST_ASSERT_EQUAL(length(spawned?.record?.chrome), 7, "The panel's cyberpsycho record lists [length(spawned?.record?.chrome)] pieces")
	var/datum/component/bounty_chrome/spawned_chrome = spawned?.GetComponent(/datum/component/bounty_chrome)
	TEST_ASSERT_EQUAL(length(spawned_chrome?.pieces), 7, "The panel's cyberpsycho carries [length(spawned_chrome?.pieces)] pieces")
	// "Post a bounty now": the board posts one wherever it can, and the forced flag never outlives the attempt
	var/datum/bounty_admin_post_action/cyberpsycho/action = new
	var/done = action.post(panel, operator)
	qdel(action)
	TEST_ASSERT(!GLOB.bounty_psycho_forced, "The panel's forced cyberpsycho outlived the attempt")
	if(done)
		TEST_ASSERT(istype(bounty_psycho_open_posting(), /datum/criminal_bounty/cyberpsycho), "The panel said it posted a cyberpsycho, but none is on the board")
	else
		TEST_ASSERT_EQUAL(panel.error, "No site would take a cyberpsycho right now.", "The panel's cyberpsycho failed with [panel.error]")

// ===== ITS PIECES WORK ONE AT A TIME =====

/**
 * The rotation: no piece starts a move on its own; each move is the boss's, and while one runs (a
 * lunge, a leap, a punch, a surge's spin-up) nothing else starts; the crash starts nothing; it never
 * uses the same move twice running while another is ready; and the Redline core takes over from
 * whatever was running, once.
 */
/datum/unit_test/voidcrew_bounty_cyberpsycho/rotation

/datum/unit_test/voidcrew_bounty_cyberpsycho/rotation/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(4, 2))
	var/mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho = psycho_at(tile(0, 2), hunter)
	var/datum/component/bounty_chrome/chrome = psycho.GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome/cascade/psycho/cascade = psycho.psycho_piece("cascade")
	var/datum/bounty_chrome/mantis/psycho/mantis = psycho.psycho_piece("mantis")
	var/datum/bounty_chrome/gorilla/psycho/gorilla = psycho.psycho_piece("gorilla")
	var/datum/bounty_chrome/piledriver/psycho/piledriver = psycho.psycho_piece("piledriver")
	var/datum/bounty_chrome/redline/psycho/redline = psycho.psycho_piece("redline")
	var/datum/bounty_chrome/deadeye/psycho/deadeye = psycho.psycho_piece("deadeye")
	var/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/surge = move_of(psycho, /datum/action/cooldown/mob_cooldown/bounty_boss/psycho/surge)
	var/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/lunge = move_of(psycho, /datum/action/cooldown/mob_cooldown/bounty_boss/psycho/lunge)
	var/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/leap = move_of(psycho, /datum/action/cooldown/mob_cooldown/bounty_boss/psycho/leap)
	var/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/punch = move_of(psycho, /datum/action/cooldown/mob_cooldown/bounty_boss/psycho/punch)
	TEST_ASSERT(surge && lunge && leap && punch, "The cyberpsycho is missing a move")
	TEST_ASSERT(bounty_chrome_fighting(psycho), "The hostile cyberpsycho isn't fighting")
	TEST_ASSERT(mantis.deployed, "Its blade didn't come out when the fight started")
	TEST_ASSERT_NULL(mantis.left_blade, "A blade came out of its Gorilla arm")

	// No piece starts anything on its own, however ready
	ready(psycho)
	for(var/i in 1 to 3)
		chrome.tick(2)
		mantis.watch()
		gorilla.on_melee_hit(hunter)
	TEST_ASSERT_EQUAL(moves_running(psycho), 0, "A piece started a move on its own")
	TEST_ASSERT_NULL(psycho.boss_busy, "A piece made it busy on its own")
	TEST_ASSERT_NULL(deadeye.mark_ref, "Its optics locked on with no move")

	// The lunge: the line, the mark, and nothing else until it is back on balance
	TEST_ASSERT(lunge.Trigger(target = hunter), "The lunge didn't start")
	TEST_ASSERT_EQUAL(mantis.lunge_state, "windup", "The lunge isn't winding up") // BOUNTY_MANTIS_WINDUP
	TEST_ASSERT_EQUAL(psycho.boss_busy, "lunge", "The lunge doesn't hold the boss") // BOUNTY_PSYCHO_BUSY_LUNGE
	TEST_ASSERT_EQUAL(deadeye.mark_ref?.resolve(), hunter, "Its optics didn't mark the lunge's target")
	TEST_ASSERT(!psycho.boss_can_use_ability(), "It may start a move mid-lunge")
	TEST_ASSERT_NULL(psycho.boss_choose_ability(hunter), "It chose a move mid-lunge")
	TEST_ASSERT(!leap.Trigger(target = hunter), "It leapt mid-lunge")
	TEST_ASSERT(!surge.Trigger(target = hunter), "It surged mid-lunge")
	chrome.tick(2)
	TEST_ASSERT_EQUAL(moves_running(psycho), 1, "Something else started mid-lunge")
	mantis.begin_dash(mantis.lunge_serial)
	for(var/i in 1 to 6)
		if(mantis.lunge_state == "dash") // BOUNTY_MANTIS_DASH
			mantis.dash_step(mantis.lunge_serial)
	TEST_ASSERT_EQUAL(mantis.lunge_state, "recover", "The dash didn't end in the recovery") // BOUNTY_MANTIS_RECOVER
	TEST_ASSERT_EQUAL(psycho.boss_busy, "lunge", "The boss was let go before the recovery was over")
	TEST_ASSERT(hunter.body_position == LYING_DOWN, "The lunge didn't cut its target down")
	mantis.end_recovery(mantis.lunge_serial)
	TEST_ASSERT_NULL(mantis.lunge_state, "The lunge never ended")
	TEST_ASSERT_NULL(psycho.boss_busy, "The lunge kept the boss after it ended")
	TEST_ASSERT(psycho.boss_next_ability_at > world.time, "No gap after the lunge")
	TEST_ASSERT(psycho.boss_next_ability_at <= world.time + 2 SECONDS, "The gap after the lunge is too long") // BOUNTY_BOSS_ABILITY_GAP_MAX
	deadeye.end_lock()

	// The leap: crouched, nothing else starts. A second hunter, on their feet: the lunge put the first down.
	var/mob/living/carbon/human/consistent/other = hunter_at(tile(4, 0))
	psycho.body_add_grudge(other)
	psycho.boss_engage(other)
	psycho.ai_controller?.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, other)
	hunter = other
	psycho.forceMove(tile(0, 0))
	ready(psycho)
	TEST_ASSERT(leap.Trigger(target = hunter), "The leap didn't start")
	TEST_ASSERT_EQUAL(piledriver.phase, 1, "The leap isn't crouching") // BOUNTY_PILEDRIVER_CROUCHING
	TEST_ASSERT_EQUAL(deadeye.mark_ref?.resolve(), hunter, "Its optics didn't mark the leap's target")
	TEST_ASSERT(!lunge.Trigger(target = hunter), "It lunged mid-leap")
	TEST_ASSERT(!surge.Trigger(target = hunter), "It surged mid-leap")
	TEST_ASSERT_EQUAL(moves_running(psycho), 1, "Something else started mid-leap")
	piledriver.end_leap()
	deadeye.end_lock()
	TEST_ASSERT_NULL(psycho.boss_busy, "The leap kept the boss after it ended")

	// The surge: the whine holds the next move back; the window doesn't; the crash starts nothing
	ready(psycho)
	TEST_ASSERT(surge.Trigger(target = hunter), "The surge didn't start")
	TEST_ASSERT_EQUAL(cascade.phase, 1, "The lattice isn't spinning up") // BOUNTY_CASCADE_SPINUP
	TEST_ASSERT(!psycho.boss_can_use_ability(), "It may start a move while the lattice spins up")
	TEST_ASSERT(!lunge.Trigger(target = hunter), "It lunged while the lattice spun up")
	cascade.open_window()
	TEST_ASSERT_EQUAL(cascade.phase, 2, "The window didn't open") // BOUNTY_CASCADE_WINDOW
	psycho.boss_next_ability_at = 0
	TEST_ASSERT(psycho.boss_can_use_ability(), "It may not make moves in the window")
	cascade.start_crash()
	TEST_ASSERT_EQUAL(cascade.phase, 3, "It didn't crash") // BOUNTY_CASCADE_CRASH
	TEST_ASSERT(!psycho.boss_can_use_ability(), "It may start a move in the crash")
	hunter.forceMove(tile(1, 0))
	ready(psycho)
	cascade.next_surge_at = world.time + 1 MINUTES
	TEST_ASSERT(!punch.Trigger(target = hunter), "It punched in the crash")
	cascade.end_crash()
	TEST_ASSERT_EQUAL(cascade.phase, 0, "The crash never ended") // BOUNTY_CASCADE_IDLE

	// The punch: right beside it; then never the same move twice while another is ready
	ready(psycho)
	cascade.next_surge_at = world.time + 1 MINUTES
	TEST_ASSERT(punch.Trigger(target = hunter), "The punch didn't start")
	TEST_ASSERT_EQUAL(gorilla.busy, "punch", "The punch isn't winding up") // BOUNTY_GORILLA_PUNCH
	TEST_ASSERT(!surge.Trigger(target = hunter), "It surged mid-punch")
	gorilla.stop()
	TEST_ASSERT_NULL(psycho.boss_busy, "The punch kept the boss after it stopped")
	ready(psycho)
	psycho.boss_last_ability = punch.type
	for(var/i in 1 to 20)
		var/datum/action/cooldown/mob_cooldown/bounty_boss/picked = psycho.boss_choose_ability(hunter)
		TEST_ASSERT(picked && picked != punch, "It picked [picked?.type] right after a punch with the surge ready")

	// The Redline core takes over: mid-lunge, as it tires, the lunge and any surge stop and it stands and roars
	hunter.forceMove(tile(3, 0))
	ready(psycho)
	cascade.spin_up()
	psycho.boss_next_ability_at = 0
	cascade.next_surge_at = world.time + 1 MINUTES
	TEST_ASSERT(lunge.Trigger(target = hunter), "The lunge didn't start before the core tripped")
	psycho.adjustBruteLoss(psycho.maxHealth * 0.62, forced = TRUE)
	TEST_ASSERT(psycho.boss_tired, "The cyberpsycho at 38% isn't tired")
	TEST_ASSERT_EQUAL(redline.state, 1, "The core didn't trip as it tired") // REDLINE_WINDING
	TEST_ASSERT_NULL(mantis.lunge_state, "The lunge ran on through the core tripping")
	TEST_ASSERT_EQUAL(cascade.phase, 0, "The lattice ran on through the core tripping")
	TEST_ASSERT_EQUAL(psycho.boss_busy, "redline", "It doesn't stand still for the roar") // BOUNTY_PSYCHO_BUSY_REDLINE
	deltimer(redline.burn_timer)
	redline.roar()
	psycho.boss_clear_busy()
	psycho.boss_next_ability_at = 0
	cascade.next_surge_at = 0
	TEST_ASSERT(!surge.worth_using(hunter), "It may surge in the Redline burn")
	deltimer(redline.burn_timer)
	redline.burn_out()
	TEST_ASSERT(!redline.can_trip(), "The core can trip a second time")

// ===== EMP =====

/**
 * An EMP takes every piece down at once: the window crashes, the blade goes in, it locks up. More
 * pulses slide off for a while after; then one lands again. In the burn it drops the core into its
 * collapse, and in the charge it dumps the Lazarus node.
 */
/datum/unit_test/voidcrew_bounty_cyberpsycho/emp

/datum/unit_test/voidcrew_bounty_cyberpsycho/emp/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(3, 2))
	var/mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho = psycho_at(tile(0, 2), hunter)
	var/datum/component/bounty_chrome/chrome = psycho.GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome/cascade/psycho/cascade = psycho.psycho_piece("cascade")
	var/datum/bounty_chrome/mantis/psycho/mantis = psycho.psycho_piece("mantis")
	ready(psycho)
	cascade.spin_up()
	cascade.open_window()
	TEST_ASSERT_EQUAL(cascade.phase, 2, "The window didn't open") // BOUNTY_CASCADE_WINDOW
	TEST_ASSERT(mantis.deployed, "Its blade isn't out")

	psycho.emp_act(EMP_HEAVY)
	for(var/key in chrome.pieces)
		var/datum/bounty_chrome/piece = chrome.pieces[key]
		TEST_ASSERT(!piece.online(), "Its [key] works through an EMP")
	TEST_ASSERT_EQUAL(cascade.phase, 3, "An EMP in the window didn't crash it") // BOUNTY_CASCADE_CRASH
	TEST_ASSERT(!mantis.deployed, "Its blade stayed out through an EMP")
	TEST_ASSERT(psycho.ai_hand?.held_type != /obj/item/melee/energy/blade/hardlight/cyberware_mantis, "The blade still shows in its hand") // BOUNTY_MANTIS_BLADE
	TEST_ASSERT_EQUAL(psycho.boss_busy, "stagger", "An EMP didn't lock it up")
	TEST_ASSERT(psycho.psycho_emp_shield_until > world.time, "No grace after the EMP")
	TEST_ASSERT(!psycho.boss_can_use_ability(), "It may start a move with its chrome down")

	// Back up, and another pulse straight away slides off
	for(var/key in chrome.pieces)
		var/datum/bounty_chrome/piece = chrome.pieces[key]
		piece.offline_until = world.time
	chrome.tick(2)
	TEST_ASSERT(mantis.online(), "Its blade didn't come back from the reboot")
	TEST_ASSERT(mantis.deployed, "Its blade didn't come back out after the reboot")
	psycho.emp_act(EMP_HEAVY)
	for(var/key in chrome.pieces)
		var/datum/bounty_chrome/piece = chrome.pieces[key]
		TEST_ASSERT(piece.online(), "A second pulse in the grace took its [key] down")
	// The grace over, one lands again
	psycho.psycho_emp_shield_until = 0
	psycho.emp_act(EMP_HEAVY)
	TEST_ASSERT(!mantis.online(), "A pulse after the grace slid off")

	// In the Redline burn: straight into the collapse
	var/mob/living/basic/bounty_criminal/boss/cyberpsycho/burning = psycho_at(tile(0, 4), hunter)
	var/datum/bounty_chrome/redline/psycho/redline = burning.psycho_piece("redline")
	burning.adjustBruteLoss(burning.maxHealth * 0.62, forced = TRUE)
	TEST_ASSERT_EQUAL(redline.state, 1, "The core didn't trip") // REDLINE_WINDING
	deltimer(redline.burn_timer)
	redline.roar()
	TEST_ASSERT_EQUAL(redline.state, 2, "The core isn't burning") // REDLINE_BURNING
	burning.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(redline.state, 0, "An EMP in the burn didn't end it") // REDLINE_IDLE
	TEST_ASSERT_NOTNULL(burning.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "An EMP in the burn didn't drop it into the collapse")

	// In the Lazarus charge: the node dumps
	var/mob/living/basic/bounty_criminal/boss/cyberpsycho/charging = psycho_at(tile(2, 4), hunter)
	var/datum/bounty_chrome/lazarus/lazarus = charging.psycho_piece("lazarus")
	charging.adjustBruteLoss(charging.maxHealth * 0.8, forced = TRUE)
	TEST_ASSERT(charging.downed, "The cyberpsycho at 20% isn't down")
	TEST_ASSERT(lazarus.charging, "The Lazarus node didn't charge as it went down")
	charging.emp_act(EMP_HEAVY)
	TEST_ASSERT(!lazarus.charging, "An EMP didn't dump the Lazarus charge")
	TEST_ASSERT(charging.downed, "It got up after its charge was dumped")

// ===== THE CAPTURE =====

/**
 * The capture: the Redline collapse is a stun that cuffs go on in, and pays in full; downed, the
 * Lazarus node stands it up once, and cuffs going on hold the charge till it fizzles; downed again,
 * it stays down.
 */
/datum/unit_test/voidcrew_bounty_cyberpsycho/capture

/datum/unit_test/voidcrew_bounty_cyberpsycho/capture/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(4, 2))
	var/mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho = psycho_at(tile(0, 2), hunter)
	var/datum/bounty_chrome/redline/psycho/redline = psycho.psycho_piece("redline")
	psycho.adjustBruteLoss(psycho.maxHealth * 0.62, forced = TRUE)
	deltimer(redline.burn_timer)
	redline.roar()
	deltimer(redline.burn_timer)
	redline.burn_out()
	TEST_ASSERT_NOTNULL(psycho.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "The cyberpsycho didn't collapse into stamina crit")
	TEST_ASSERT_EQUAL(psycho.capture_state(), "stunned", "Collapsed, it doesn't count as stunned") // BOUNTY_STATE_STUNNED
	TEST_ASSERT(psycho.body_apply_cuffs(allocate(/obj/item/restraints/handcuffs, tile(0, 2))), "Cuffs didn't go on the collapsed cyberpsycho")
	TEST_ASSERT_EQUAL(psycho.capture_state(), "restrained", "Cuffed, it doesn't count as restrained") // BOUNTY_STATE_RESTRAINED
	var/datum/criminal_bounty/cyberpsycho/posting = new
	TEST_ASSERT_EQUAL(posting.board_share_for(psycho.capture_state(), psycho.worst_state), 100, "Cuffed in the collapse, it doesn't pay in full")
	qdel(posting)

	// Downed: the node stands it up once
	var/mob/living/basic/bounty_criminal/boss/cyberpsycho/second = psycho_at(tile(0, 4), hunter)
	var/datum/bounty_chrome/lazarus/lazarus = second.psycho_piece("lazarus")
	var/datum/bounty_chrome/redline/psycho/second_core = second.psycho_piece("redline")
	second_core.psycho_spent = TRUE
	second.adjustBruteLoss(second.maxHealth * 0.8, forced = TRUE)
	TEST_ASSERT(second.downed, "The cyberpsycho at 20% isn't down")
	TEST_ASSERT(lazarus.charging, "The Lazarus node didn't charge")
	TEST_ASSERT(lazarus.discharge(lazarus.charge_serial), "The Lazarus node didn't stand it up")
	TEST_ASSERT(!second.downed, "It is still down after the jolt")
	TEST_ASSERT(second.health >= second.maxHealth * 0.34, "It got up at [second.health] of [second.maxHealth]") // BOUNTY_RECOVER_TO
	// Down again: no second jolt, and cuffs go on
	second.adjustBruteLoss(second.maxHealth * 0.2, forced = TRUE)
	TEST_ASSERT(second.downed, "It isn't down the second time")
	TEST_ASSERT(!lazarus.charging, "The Lazarus node charged twice")
	TEST_ASSERT(second.body_apply_cuffs(allocate(/obj/item/restraints/handcuffs, tile(0, 4))), "Cuffs didn't go on the downed cyberpsycho")
	TEST_ASSERT_EQUAL(second.capture_state(), "downed", "Cuffed while down, it doesn't count as downed") // BOUNTY_STATE_DOWNED
	var/datum/criminal_bounty/cyberpsycho/second_posting = new
	TEST_ASSERT_EQUAL(second_posting.board_share_for(second.capture_state(), second.worst_state), 60, "Downed, it doesn't pay the downed share") // BOUNTY_SHARE_DOWNED
	qdel(second_posting)

	// Cuffs going on during the charge hold it, and it fizzles
	var/mob/living/basic/bounty_criminal/boss/cyberpsycho/third = psycho_at(tile(2, 4), hunter)
	var/datum/bounty_chrome/lazarus/third_node = third.psycho_piece("lazarus")
	third.adjustBruteLoss(third.maxHealth * 0.8, forced = TRUE)
	TEST_ASSERT(third_node.charging, "The third cyberpsycho's node didn't charge")
	TEST_ASSERT(third.body_apply_cuffs(allocate(/obj/item/restraints/handcuffs, tile(2, 4))), "Cuffs didn't go on the charging cyberpsycho")
	TEST_ASSERT(!third_node.charging, "Cuffs on a charging cyberpsycho didn't stop the charge")
	TEST_ASSERT(third.downed, "The cuffed cyberpsycho got up")

// ===== CLEAN-UP =====

/// Dead, nothing it had going is left on it; deleted mid-move, nothing is left on the floor or on its target
/datum/unit_test/voidcrew_bounty_cyberpsycho/cleanup

/datum/unit_test/voidcrew_bounty_cyberpsycho/cleanup/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(4, 2))
	var/mob/living/basic/bounty_criminal/boss/cyberpsycho/psycho = psycho_at(tile(0, 2), hunter)
	var/datum/bounty_chrome/cascade/psycho/cascade = psycho.psycho_piece("cascade")
	var/datum/bounty_chrome/mantis/psycho/mantis = psycho.psycho_piece("mantis")
	ready(psycho)
	cascade.spin_up()
	cascade.open_window()
	TEST_ASSERT(psycho.has_movespeed_modifier(/datum/movespeed_modifier/bounty_cascade), "The window didn't speed it up")
	psycho.death()
	TEST_ASSERT(!psycho.has_movespeed_modifier(/datum/movespeed_modifier/bounty_cascade), "The window's pace outlived it")
	TEST_ASSERT(!psycho.has_movespeed_modifier(/datum/movespeed_modifier/bounty_cascade_crash), "The crash's pace outlived it")
	TEST_ASSERT_NULL(psycho.get_filter("bounty_cascade_glow"), "The lattice's glow outlived it")
	TEST_ASSERT_EQUAL(cascade.phase, 0, "The lattice is still running on a dead body")
	TEST_ASSERT(!mantis.deployed, "Its blade is still out on a dead body")
	TEST_ASSERT_NULL(psycho.ai_hand, "Something is still in its dead hand")
	TEST_ASSERT_NULL(psycho.boss_busy, "A dead body is still busy")
	for(var/source in list("bounty_chrome_mantis", "bounty_chrome_gorilla", "bounty_boss_busy")) // BOUNTY_MANTIS_TRAIT, BOUNTY_GORILLA_TRAIT, BOUNTY_BOSS_BUSY_TRAIT
		TEST_ASSERT(!HAS_TRAIT_FROM(psycho, TRAIT_IMMOBILIZED, source), "A dead body is held still by [source]")

	// Deleted mid-lunge: its marks go, its target's glint goes, and its pieces let go of it
	var/mob/living/basic/bounty_criminal/boss/cyberpsycho/lunger = psycho_at(tile(0, 0), hunter)
	hunter.forceMove(tile(3, 0))
	var/datum/bounty_chrome/mantis/psycho/lunger_blade = lunger.psycho_piece("mantis")
	var/datum/bounty_chrome/deadeye/psycho/optics = lunger.psycho_piece("deadeye")
	var/datum/action/cooldown/mob_cooldown/bounty_boss/psycho/lunge = move_of(lunger, /datum/action/cooldown/mob_cooldown/bounty_boss/psycho/lunge)
	ready(lunger)
	TEST_ASSERT(lunge.Trigger(target = hunter), "The lunge didn't start")
	var/mark_filter = optics.mark_filter
	TEST_ASSERT_NOTNULL(hunter.get_filter(mark_filter), "The lunge's target isn't marked")
	var/list/datum/bounty_chrome/pieces = list()
	var/datum/component/bounty_chrome/chrome = lunger.GetComponent(/datum/component/bounty_chrome)
	for(var/key in chrome.pieces)
		pieces += chrome.pieces[key]
	qdel(lunger)
	TEST_ASSERT_NULL(hunter.get_filter(mark_filter), "The mark outlived the cyberpsycho")
	TEST_ASSERT_NULL(lunger_blade.lunge_marks, "The lunge's line outlived the cyberpsycho")
	for(var/datum/bounty_chrome/piece as anything in pieces)
		TEST_ASSERT_NULL(piece.owner, "Its [piece.type] kept hold of the deleted cyberpsycho")

// ===== ITS LOOK =====

/**
 * The look: an arm takes one piece, so the blade housing goes on its right arm and the Gorilla
 * plating on its left, and its shorts leave every piece showing. Not only a check: draws it, three
 * species, every way it faces, with and without the blade out, to data/bounty_chrome_renders/.
 */
/datum/unit_test/voidcrew_bounty_cyberpsycho/renders

/datum/unit_test/voidcrew_bounty_cyberpsycho/renders/Run()
	var/list/organs = bounty_chrome_organ_looks(bounty_psycho_chrome_keys())
	TEST_ASSERT(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis in organs, "No blade housing on its right arm")
	TEST_ASSERT(/obj/item/organ/cyberimp/cyberware/gorilla_arms/left in organs, "No Gorilla plating on its left arm")
	TEST_ASSERT(!(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left in organs), "A blade housing took its left arm too")
	TEST_ASSERT(!(/obj/item/organ/cyberimp/cyberware/gorilla_arms in organs), "Gorilla plating took its right arm too")
	TEST_ASSERT(/obj/item/organ/cyberimp/cyberware/piledriver in organs, "No piledriver frame in its look")
	// One implant to a slot: the core and the lattice share one, and the core is listed first
	TEST_ASSERT(/obj/item/organ/cyberimp/cyberware/redline in organs, "No Redline core in its look")
	TEST_ASSERT(!(/obj/item/organ/cyberimp/cyberware/cascade in organs), "The lattice would push the core out of its slot")
	// Alone, either still takes both arms
	TEST_ASSERT_EQUAL(length(bounty_chrome_organ_looks(list("gorilla"))), 2, "Gorilla Arms alone don't take both arms") // BOUNTY_CHROME_GORILLA
	TEST_ASSERT_EQUAL(length(bounty_chrome_organ_looks(list("mantis"))), 2, "Mantis Blades alone don't take both arms") // BOUNTY_CHROME_MANTIS

	var/list/bodies = list(
		"human" = list(/datum/species/human, MALE),
		"lizard" = list(/datum/species/lizard, FEMALE),
		"moth" = list(/datum/species/moth, MALE),
	)
	for(var/body_name in bodies)
		var/list/spec = bodies[body_name]
		var/datum/bounty_look/look = bounty_roll_look(spec[1], spec[2])
		var/mob/living/carbon/human/dummy/dummy = bounty_look_dummy(look, /datum/outfit/bounty_boss/cyberpsycho, null, chrome_organs = organs, expose_chrome = FALSE)
		TEST_ASSERT_NOTNULL(dummy, "The [body_name] cyberpsycho's look failed")
		if(!dummy)
			continue
		TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis) in dummy.organs, "The [body_name] cyberpsycho has no blade housing")
		TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/left) in dummy.organs, "The [body_name] cyberpsycho has no Gorilla plating")
		TEST_ASSERT_NULL(dummy.wear_suit, "The [body_name] cyberpsycho wears something over its chest")
		TEST_ASSERT_NULL(dummy.gloves, "The [body_name] cyberpsycho wears gloves over its arms")
		TEST_ASSERT_NULL(dummy.shoes, "The [body_name] cyberpsycho wears shoes over its pistons")
		for(var/facing in list(SOUTH, NORTH, EAST, WEST))
			fcopy(getFlatIcon(dummy, facing), "data/bounty_chrome_renders/cyberpsycho_[body_name]_[dir2text(facing)].png")
		// In the fight: the blade out in its right hand
		var/obj/item/blade = new /obj/item/melee/energy/blade/hardlight/cyberware_mantis(dummy) // BOUNTY_MANTIS_BLADE
		dummy.put_in_r_hand(blade)
		fcopy(getFlatIcon(dummy, SOUTH), "data/bounty_chrome_renders/cyberpsycho_[body_name]_blade_south.png")
		fcopy(getFlatIcon(dummy, EAST), "data/bounty_chrome_renders/cyberpsycho_[body_name]_blade_east.png")
		qdel(dummy)

	// "All of it" on an ordinary criminal: the same arms, and the clothes off where the chrome is
	var/datum/bounty_look/plain = bounty_roll_look(/datum/species/human, MALE)
	var/mob/living/carbon/human/dummy/everything = bounty_look_dummy(plain, /datum/outfit/bounty_criminal/tough, null, chrome_organs = bounty_chrome_organ_looks(bounty_psycho_chrome_keys()))
	TEST_ASSERT_NOTNULL(everything, "All of it on an ordinary criminal failed")
	if(everything)
		fcopy(getFlatIcon(everything, SOUTH), "data/bounty_chrome_renders/cyberpsycho_all_of_it_tough_south.png")
		qdel(everything)
