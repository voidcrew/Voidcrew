/**
 * Outpost floors (voidcrew/modules/trade_floors/): tests of package P3.
 * Owner: P3. Subtype /datum/unit_test/voidcrew_outpost_floors and use the helpers in
 * voidcrew_outpost_floors_helpers.dm (P0, frozen). Fork defines are included after the tests: write the literal
 * value with a comment naming the define. Pin other packages' outputs directly and never wait for an AI walk.
 *
 * The console (trade_floors/floor_tenancy.dm): who holds a lease and how it changes hands, the floor's name, line and
 * colour, the guest and barred lists, and hired hands. No client ever connects to a test world, so players are bodies
 * with offline keys, a hire's yes is given by calling tenancy_hire_answer(), and an owner's absence is a time written
 * straight into the host.
 */

/// Parent of the tenancy tests. It never runs.
/datum/unit_test/voidcrew_outpost_floors/tenancy
	abstract_type = /datum/unit_test/voidcrew_outpost_floors/tenancy
	/// Crews made by same_crew()
	var/list/datum/voidcrew_crew_record/made_crews = list()
	/// Minds with no body, made by loose_mind()
	var/list/datum/mind/made_minds = list()

/datum/unit_test/voidcrew_outpost_floors/tenancy/Destroy()
	// These offline keys stand in for players without connecting a client to the test world
	for(var/mob/player in allocated)
		if(QDELETED(player))
			continue
		player.key = null
		// shipmates() put a team on the mind's roster by hand: take it off the same way
		if(player.mind)
			player.mind.ship_teams = null
	QDEL_LIST(made_crews)
	QDEL_LIST(made_minds)
	return ..()

/// A player's character at `where`: a body with a key and a mind, and no client
/datum/unit_test/voidcrew_outpost_floors/tenancy/proc/player(turf/where, player_key)
	var/mob/living/carbon/human/made = test_person(where)
	made.key = player_key
	made.mind_initialize()
	return made

/// A mind with no body, for filling a list
/datum/unit_test/voidcrew_outpost_floors/tenancy/proc/loose_mind(mind_name)
	var/datum/mind/made = new(null)
	made.name = mind_name
	made_minds += made
	return made

/// Puts every mob given on one ship's roster: a team they share, which is how the floors' rules know a ship crew
/datum/unit_test/voidcrew_outpost_floors/tenancy/proc/shipmates(...)
	var/datum/team/voidcrew/team = allocate(/datum/team/voidcrew)
	for(var/mob/living/member as anything in args)
		LAZYADD(member.mind.ship_teams, team)
	return team

/// Puts every mob given on one crew and on no ship: what is left of a ship crew whose members have been through cryo
/datum/unit_test/voidcrew_outpost_floors/tenancy/proc/same_crew(...)
	var/datum/voidcrew_crew_record/crew = new
	made_crews += crew
	for(var/mob/living/member as anything in args)
		member.mind.join_reputation_crew(crew)
	return crew

/// Floor `number` of `outpost` with its host, let to `owner`. Its state is "owned" and its setting "crew".
/datum/unit_test/voidcrew_outpost_floors/tenancy/proc/let_floor(obj/structure/overmap/trader_outpost/outpost, number, mob/living/owner)
	var/datum/outpost_floor/floor = test_floor(outpost, number, 14, 12, TRUE)
	if(!floor)
		return null
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	host.loaded = TRUE
	floor.floor_name = "Floor [number]"
	host.founder_ckey = owner.ckey
	host.founder_name = owner.real_name
	host.founder_mind = WEAKREF(owner.mind)
	host.residents |= owner.mind
	return floor

/// A crewmate takes over the lease of an owner gone fifteen minutes; nobody else does, and never sooner (spec 7, A26)
/datum/unit_test/voidcrew_outpost_floors/tenancy/takeover

/datum/unit_test/voidcrew_outpost_floors/tenancy/takeover/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/mob/living/owner = player(run_loc_floor_bottom_left, "tenancytakeowner")
	var/datum/outpost_floor/floor = let_floor(outpost, 1, owner)
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/turf/deck = deck_tile(floor)
	var/mob/living/mate = player(deck, "tenancytakemate")
	var/mob/living/lodger = player(deck, "tenancytakelodger")
	var/mob/living/hand = player(deck, "tenancytakehand")
	var/mob/living/stranger = player(deck, "tenancytakestranger")
	shipmates(owner, mate)
	// The lodger moved in from the lobby and was made a steward: still not the owner's crew
	host.residents |= lodger.mind
	host.stewards |= lodger.mind
	floor.hands += hand.mind

	TEST_ASSERT(!host.can_take_over(mate), "A crewmate could take over the moment the owner was found gone")
	TEST_ASSERT(host.tenancy_owner_gone_at > 0, "Nothing noted when the owner was first found gone")
	host.tenancy_owner_gone_at = world.time - 14 MINUTES
	TEST_ASSERT(!host.can_take_over(mate), "A crewmate could take over fourteen minutes after the owner went")
	host.tenancy_owner_gone_at = world.time - 16 MINUTES // OUTPOST_FLOOR_OWNER_ABSENT is 15 MINUTES
	TEST_ASSERT(host.can_take_over(mate), "The owner's crewmate could not take over sixteen minutes after the owner went")
	TEST_ASSERT(host.can_claim(mate), "The console would not open its controls to a crewmate who may take over")
	TEST_ASSERT(!host.can_take_over(lodger), "A resident from the lobby could take over the lease (A26)")
	TEST_ASSERT(!host.can_take_over(hand), "A hired hand could take over the lease")
	TEST_ASSERT(!host.can_take_over(stranger), "A stranger could take over the lease")
	TEST_ASSERT(!host.can_take_over(owner), "An owner could take over their own lease")
	TEST_ASSERT(!host.can_claim(stranger), "A stranger could claim a floor that has an owner")

	mate.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(!host.can_take_over(mate), "A lease was taken over from off the floor")
	mate.forceMove(deck)
	host.blocked_residents |= mate.ckey
	TEST_ASSERT(!host.can_take_over(mate), "A player the owner blocked could take over")
	host.blocked_residents -= mate.ckey

	TEST_ASSERT(host.floor_ui_act("floor_take_over", list(), lodger), "The console did not know floor_take_over")
	TEST_ASSERT_EQUAL(host.founder_ckey, owner.ckey, "A lobby resident's click took the lease")
	TEST_ASSERT(!host.transfer_ownership(stranger, stranger), "A stranger took an owned floor by claiming it")
	host.floor_ui_act("floor_take_over", list(), mate)
	TEST_ASSERT_EQUAL(host.founder_ckey, mate.ckey, "The crewmate's takeover did not change the holder")
	TEST_ASSERT_EQUAL(floor.state, "owned", "A takeover left the floor in another state") // OUTPOST_FLOOR_STATE_OWNED
	TEST_ASSERT_EQUAL(floor.entry_policy, "crew", "A takeover changed who may come up") // OUTPOST_FLOOR_ENTRY_CREW
	TEST_ASSERT_EQUAL(length(floor.hands), 0, "Hands outlasted a takeover (A80)")
	TEST_ASSERT(lodger.mind in host.residents, "A takeover put the floor's residents off its books")
	TEST_ASSERT(!(lodger.mind in host.stewards), "A takeover kept the old owner's steward")
	TEST_ASSERT_EQUAL(host.tenancy_owner_gone_at, 0, "The old owner's absence was counted against the new one")
	TEST_ASSERT(!host.can_take_over(owner), "The old owner could take the lease straight back")

/// An owner who went through cryo is on no ship's roster: their crew is still their crew, and may take over
/datum/unit_test/voidcrew_outpost_floors/tenancy/takeover_after_cryo

/datum/unit_test/voidcrew_outpost_floors/tenancy/takeover_after_cryo/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/mob/living/owner = player(run_loc_floor_bottom_left, "tenancycryoowner")
	var/datum/outpost_floor/floor = let_floor(outpost, 1, owner)
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/turf/deck = deck_tile(floor)
	var/mob/living/mate = player(deck, "tenancycryomate")
	var/mob/living/other = player(deck, "tenancycryoother")
	var/mob/living/loner = player(deck, "tenancycryoloner")
	same_crew(owner, mate)
	same_crew(other)
	host.tenancy_owner_gone_at = world.time - 16 MINUTES // OUTPOST_FLOOR_OWNER_ABSENT is 15 MINUTES
	TEST_ASSERT(host.can_take_over(mate), "The crew of an owner on no ship's roster could not take over")
	TEST_ASSERT(!host.can_take_over(other), "Someone of another crew could take over")
	TEST_ASSERT(!host.can_take_over(loner), "Someone of no crew could take over")
	TEST_ASSERT(host.transfer_ownership(mate, mate), "The takeover by the owner's crew failed")
	TEST_ASSERT_EQUAL(host.founder_ckey, mate.ckey, "The takeover did not change the holder")

/// Owner decision 5: a floor nobody has touched for five hours is still its owner's, and nobody but their crew can take it
/datum/unit_test/voidcrew_outpost_floors/tenancy/never_lapses

/datum/unit_test/voidcrew_outpost_floors/tenancy/never_lapses/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/mob/living/owner = player(run_loc_floor_bottom_left, "tenancylapseowner")
	var/datum/outpost_floor/floor = let_floor(outpost, 1, owner)
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/turf/deck = deck_tile(floor)
	var/mob/living/lodger = player(deck, "tenancylapselodger")
	var/mob/living/stranger = player(deck, "tenancylapsestranger")
	host.residents |= lodger.mind
	floor.guests += stranger.mind
	host.tenancy_owner_gone_at = world.time - 5 HOURS

	for(var/mob/living/asker as anything in list(lodger, stranger))
		TEST_ASSERT_NOTNULL(host.floor_ui_data(asker), "The console had nothing to show on a floor")
		TEST_ASSERT(!host.can_take_over(asker), "[asker.ckey] could take over a floor left five hours")
		TEST_ASSERT(!host.can_claim(asker), "[asker.ckey] could claim a floor left five hours")
		host.floor_ui_act("floor_take_over", list(), asker)
		TEST_ASSERT(!host.transfer_ownership(asker, asker), "[asker.ckey] took a floor left five hours")
	TEST_ASSERT_EQUAL(host.founder_ckey, owner.ckey, "A floor left five hours changed hands")
	TEST_ASSERT_EQUAL(floor.state, "owned", "A floor left five hours is no longer owned") // OUTPOST_FLOOR_STATE_OWNED
	TEST_ASSERT_EQUAL(floor.entry_policy, "crew", "A floor left five hours opened its lift") // OUTPOST_FLOOR_ENTRY_CREW
	TEST_ASSERT(stranger.mind in floor.guests, "A floor left five hours lost its guest list")
	var/list/owner_data = host.floor_ui_data(owner)
	TEST_ASSERT(owner_data["can_give_up"], "After five hours the owner cannot give up their own floor")

/// A floor its owner gave up stands vacant as it is, and is taken by someone whose crew holds none (A24)
/datum/unit_test/voidcrew_outpost_floors/tenancy/claim_cap

/datum/unit_test/voidcrew_outpost_floors/tenancy/claim_cap/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/mob/living/first_owner = player(run_loc_floor_bottom_left, "tenancyclaimfirst")
	var/mob/living/second_owner = player(run_loc_floor_bottom_left, "tenancyclaimsecond")
	var/datum/outpost_floor/first = let_floor(outpost, 1, first_owner)
	var/datum/outpost_floor/second = let_floor(outpost, 2, second_owner)
	if(!first || !second)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/first_host = first.host
	var/obj/structure/overmap/dynamic/player_outpost/floor/second_host = second.host
	var/mob/living/claimant = player(deck_tile(first), "tenancyclaimtaker")
	var/mob/living/mate = player(deck_tile(second), "tenancyclaimmate")
	var/mob/living/stranger = player(deck_tile(second), "tenancyclaimstranger")
	shipmates(claimant, mate)
	first.hands += loose_mind("Claim Hand")
	first.guests += loose_mind("Claim Guest")
	first.barred += loose_mind("Claim Barred")
	first.board_line = "Fresh bread."
	first.floor_name = "The Old Crew"
	first.entry_policy = "invited" // OUTPOST_FLOOR_ENTRY_INVITED

	TEST_ASSERT(!first_host.can_claim(claimant), "A floor with an owner could be claimed")
	first_host.abandon(claimant)
	TEST_ASSERT_EQUAL(first_host.founder_ckey, first_owner.ckey, "Somebody else gave up the owner's floor")
	first_host.abandon(first_owner)
	TEST_ASSERT_NULL(first_host.founder_ckey, "The owner could not give up the floor")
	TEST_ASSERT_EQUAL(first.state, "vacant", "A floor given up is not vacant") // OUTPOST_FLOOR_STATE_VACANT
	TEST_ASSERT_EQUAL(first.entry_policy, "open", "Nobody can ride up to take a vacant floor") // OUTPOST_FLOOR_ENTRY_OPEN
	TEST_ASSERT_EQUAL(length(first.hands) + length(first.guests) + length(first.barred), 0, "A floor given up kept its hands or its lists (A98)")
	TEST_ASSERT_EQUAL(first.board_line, "", "A floor given up kept its old crew's line")
	TEST_ASSERT(!first_host.can_take_over(claimant), "A vacant floor was taken over, not claimed")

	TEST_ASSERT_NULL(first_host.claim_denial(claimant), "Someone holding no floor was refused a vacant one")
	TEST_ASSERT(first_host.can_claim(claimant), "Someone holding no floor could not claim a vacant one")
	TEST_ASSERT(first_host.transfer_ownership(claimant, claimant), "The claim of a vacant floor failed")
	TEST_ASSERT_EQUAL(first_host.founder_ckey, claimant.ckey, "The claimant does not hold the floor they claimed")
	TEST_ASSERT_EQUAL(first.state, "owned", "A claimed floor is not owned") // OUTPOST_FLOOR_STATE_OWNED
	TEST_ASSERT_EQUAL(first.entry_policy, "crew", "A claimed floor did not start Crew only") // OUTPOST_FLOOR_ENTRY_CREW
	TEST_ASSERT_EQUAL(first.floor_name, "Floor 1", "A floor claimed by someone with no ship kept its old crew's name")

	// With one held: the claimant, and their crewmate, are refused a second
	second_host.abandon(second_owner)
	claimant.forceMove(deck_tile(second))
	TEST_ASSERT_NOTNULL(second_host.claim_denial(claimant), "The holder of a floor was not refused a second (A24)")
	TEST_ASSERT(!second_host.can_claim(claimant), "The holder of a floor could claim a second (A24)")
	TEST_ASSERT(!second_host.transfer_ownership(claimant, claimant), "The holder of a floor took a second (A24)")
	TEST_ASSERT(!second_host.can_claim(mate), "A crew that holds a floor could claim a second through a crewmate (A24)")
	TEST_ASSERT(second_host.can_claim(stranger), "A stranger holding nothing could not claim the other vacant floor")
	var/list/claim_data = second_host.floor_ui_data(mate)
	TEST_ASSERT_NOTNULL(claim_data["floor_claim_denial"], "The console does not say why a second floor is refused")

/// A gift obeys one floor a crew, passes within a crew, and takes the hands with it (A24, A80)
/datum/unit_test/voidcrew_outpost_floors/tenancy/gift_cap

/datum/unit_test/voidcrew_outpost_floors/tenancy/gift_cap/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/mob/living/giver = player(run_loc_floor_bottom_left, "tenancygiftgiver")
	var/mob/living/other_owner = player(run_loc_floor_bottom_left, "tenancygiftother")
	var/datum/outpost_floor/floor = let_floor(outpost, 1, giver)
	var/datum/outpost_floor/other_floor = let_floor(outpost, 2, other_owner)
	if(!floor || !other_floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/turf/deck = deck_tile(floor)
	giver.forceMove(deck)
	other_owner.forceMove(deck)
	var/mob/living/mate = player(deck, "tenancygiftmate")
	var/mob/living/other_mate = player(deck, "tenancygiftothermate")
	shipmates(giver, mate)
	shipmates(other_owner, other_mate)
	floor.hands += loose_mind("Gift Hand")

	TEST_ASSERT(!host.transfer_ownership(other_owner, giver), "A floor was given to the holder of another (A24)")
	TEST_ASSERT(!host.transfer_ownership(other_mate, giver), "A floor was given to the crew of another's holder (A24)")
	TEST_ASSERT_EQUAL(host.founder_ckey, giver.ckey, "A refused gift changed the holder")
	TEST_ASSERT_EQUAL(length(floor.hands), 1, "A refused gift let the hands go")
	TEST_ASSERT(host.transfer_ownership(mate, giver), "The owner could not give the floor to their own crewmate")
	TEST_ASSERT_EQUAL(host.founder_ckey, mate.ckey, "A gift did not change the holder")
	TEST_ASSERT_EQUAL(floor.state, "owned", "A given floor is not owned") // OUTPOST_FLOOR_STATE_OWNED
	TEST_ASSERT_EQUAL(length(floor.hands), 0, "Hands outlasted a gift (A80)")

/// The name, the line and the colour: cleaned where they are typed, bounded, and only theirs to set (L31, A43, A90)
/datum/unit_test/voidcrew_outpost_floors/tenancy/identity

/datum/unit_test/voidcrew_outpost_floors/tenancy/identity/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/mob/living/owner = player(run_loc_floor_bottom_left, "tenancynameowner")
	var/datum/outpost_floor/floor = let_floor(outpost, 1, owner)
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/turf/deck = deck_tile(floor)
	owner.forceMove(deck)
	var/mob/living/steward = player(deck, "tenancynamesteward")
	var/mob/living/stranger = player(deck, "tenancynamestranger")
	host.residents |= steward.mind
	host.stewards |= steward.mind

	// The name
	TEST_ASSERT(floor.set_name("  The   Rusty\tAnchor \n", owner), "The owner could not name the floor")
	TEST_ASSERT_EQUAL(floor.floor_name, "The Rusty Anchor", "A name was not made one tidy line")
	TEST_ASSERT_EQUAL(host.name, "The Rusty Anchor", "The floor's host does not carry its name")
	TEST_ASSERT(!floor.set_name("Second Thoughts", owner), "A floor was renamed twice inside the cooldown") // PLAYER_OUTPOST_RENAME_COOLDOWN
	floor.tenancy_rename_ready_at = 0
	TEST_ASSERT(floor.set_name("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", owner), "A long name was refused, not cut")
	TEST_ASSERT_EQUAL(floor.floor_name, "ABCDEFGHIJKLMNOPQRSTUVWX", "A long name was not cut at 24") // OUTPOST_FLOOR_NAME_MAX
	floor.tenancy_rename_ready_at = 0
	for(var/bad in list("<b>Bold</b>", "Half<", "a/b", "back\\slash", "   ", "", "na[ascii2text(239)]ve", 5, null, list("x")))
		TEST_ASSERT(!floor.set_name(bad, owner), "A floor took [istext(bad) ? "'[bad]'" : "something that is not text"] for its name")
	TEST_ASSERT_EQUAL(floor.floor_name, "ABCDEFGHIJKLMNOPQRSTUVWX", "A refused name changed the floor's")
	TEST_ASSERT_EQUAL(floor.tenancy_rename_ready_at, 0, "A refused name started the cooldown")
	TEST_ASSERT(!floor.set_name("Stewards Rest", steward), "A steward renamed the floor")
	TEST_ASSERT(!floor.set_name("Squatters", stranger), "A stranger renamed the floor")
	// The outposts' own rename is announced to every ship: on a floor it goes to the floor's, and by its rules
	TEST_ASSERT(!host.set_outpost_name("Stewards Rest", steward), "A steward renamed the floor through the outposts' rename")
	TEST_ASSERT(host.set_outpost_name("The Long Way Round", owner), "The owner's rename by the outposts' action failed")
	TEST_ASSERT_EQUAL(floor.floor_name, "The Long Way Round", "The outposts' rename did not name the floor")
	TEST_ASSERT(!host.set_outpost_name("A name that runs on far too long to be a floor's and has <b>this</b> in it", owner), "The outposts' rename took what a floor's name refuses")

	// The line
	TEST_ASSERT(floor.set_line("Fresh bread,  cold beer.", owner), "The owner could not set the board line")
	TEST_ASSERT_EQUAL(floor.board_line, "Fresh bread, cold beer.", "A line was not made one tidy line")
	var/long_line = "0123456789012345678901234567890123456789012345678901234567890123456789"
	TEST_ASSERT(floor.set_line(long_line, owner), "A long line was refused, not cut")
	TEST_ASSERT_EQUAL(length(floor.board_line), 60, "A long line was not cut at 60") // OUTPOST_FLOOR_LINE_MAX
	for(var/bad in list("<script>", "see /here", 7, null))
		TEST_ASSERT(!floor.set_line(bad, owner), "A floor took [istext(bad) ? "'[bad]'" : "something that is not text"] for its line")
	TEST_ASSERT_EQUAL(length(floor.board_line), 60, "A refused line changed the floor's")
	TEST_ASSERT(!floor.set_line("Under new management", steward), "A steward set the board line")
	TEST_ASSERT(floor.set_line("   ", owner), "The owner could not clear the board line")
	TEST_ASSERT_EQUAL(floor.board_line, "", "An empty line did not clear the board line")

	// The colour
	TEST_ASSERT(floor.set_accent("rose", steward), "A steward could not pick the colour") // OUTPOST_FLOOR_ACCENT_ROSE
	TEST_ASSERT(!floor.set_accent("teal", stranger), "A stranger picked the colour") // OUTPOST_FLOOR_ACCENT_TEAL
	for(var/bad in list("#ff0000", "ROSE", "<b>teal</b>", "", 3, null))
		TEST_ASSERT(!floor.set_accent(bad, owner), "A floor took [istext(bad) ? "'[bad]'" : "something that is not text"] for its colour (A90)")
	host.floor_ui_act("floor_set_accent", list("accent" = "#ffffff"), owner)
	TEST_ASSERT_EQUAL(floor.accent, "rose", "A refused colour changed the floor's")
	TEST_ASSERT_EQUAL(floor.accent_colour(), "#d86a9c", "Rose is not rose")

/// The guest list and the barred list hold thirty each, minds and ships only, and a deleted entry leaves them (A36)
/datum/unit_test/voidcrew_outpost_floors/tenancy/list_caps

/datum/unit_test/voidcrew_outpost_floors/tenancy/list_caps/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/mob/living/owner = player(run_loc_floor_bottom_left, "tenancylistowner")
	var/datum/outpost_floor/floor = let_floor(outpost, 1, owner)
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/turf/deck = deck_tile(floor)
	owner.forceMove(deck)
	var/mob/living/steward = player(deck, "tenancyliststeward")
	var/mob/living/stranger = player(deck, "tenancyliststranger")
	host.residents |= steward.mind
	host.stewards |= steward.mind

	var/list/datum/mind/invited = list()
	for(var/count in 1 to 30) // OUTPOST_FLOOR_LIST_MAX
		var/datum/mind/guest = loose_mind("Guest [count] of a Long Family Name")
		invited += guest
		TEST_ASSERT(floor.tenancy_add_guest(guest, owner), "Guest [count] of thirty was refused")
	var/datum/mind/one_more = loose_mind("One More")
	TEST_ASSERT(!floor.tenancy_add_guest(one_more, owner), "A thirty-first guest was listed")
	TEST_ASSERT(!floor.tenancy_add_guest(invited[1], owner), "A guest was listed twice")
	TEST_ASSERT_EQUAL(length(floor.guests), 30, "The guest list is not thirty long")
	TEST_ASSERT(!floor.tenancy_add_guest(one_more, stranger), "A stranger put someone on the guest list")
	TEST_ASSERT(!floor.tenancy_add_guest(outpost, owner), "Something that is no person and no ship was put on the guest list")
	TEST_ASSERT(!floor.tenancy_add_barred(null, owner), "Nothing at all was barred")

	// Barring a guest takes them off the guest list, and a bar is lifted by putting them back on it
	TEST_ASSERT(floor.tenancy_add_barred(invited[1], steward), "A steward could not bar someone")
	TEST_ASSERT(!(invited[1] in floor.guests), "A barred guest is still a guest")
	TEST_ASSERT(floor.tenancy_add_guest(invited[1], owner), "A barred person could not be invited again")
	TEST_ASSERT(!(invited[1] in floor.barred), "A guest is still barred")
	for(var/count in 1 to 30) // OUTPOST_FLOOR_LIST_MAX
		TEST_ASSERT(floor.tenancy_add_barred(loose_mind("Barred [count]"), owner), "Bar [count] of thirty was refused")
	TEST_ASSERT(!floor.tenancy_add_barred(one_more, owner), "A thirty-first person was barred")
	TEST_ASSERT_EQUAL(length(floor.barred), 30, "The barred list is not thirty long")

	// A barred hand is let go
	var/datum/mind/worker = loose_mind("Worker")
	floor.hands += worker
	floor.tenancy_remove_barred(floor.barred[1], owner)
	TEST_ASSERT(floor.tenancy_add_barred(worker, owner), "A hand could not be barred")
	TEST_ASSERT(!(worker in floor.hands), "A barred hand is still a hand")

	// What the console is sent, and what it may ask for
	var/list/data = host.floor_ui_data(owner)
	TEST_ASSERT_EQUAL(length(data["guests"]), 30, "The console was not sent thirty guests")
	TEST_ASSERT_EQUAL(length(data["barred"]), 30, "The console was not sent thirty barred")
	for(var/list/row as anything in data["guests"])
		TEST_ASSERT(length(row["name"]) <= 24, "A guest's name was sent longer than 24") // OUTPOST_FLOOR_NAME_MAX
		TEST_ASSERT_EQUAL(row["kind"], "person", "A mind was not sent as a person")
	host.floor_ui_act("floor_guest_remove", list("ref" = REF(invited[2])), stranger)
	TEST_ASSERT(invited[2] in floor.guests, "A stranger took a guest off the list at the console")
	host.floor_ui_act("floor_guest_remove", list("ref" = REF(invited[2])), steward)
	TEST_ASSERT(!(invited[2] in floor.guests), "A steward could not take a guest off the list at the console")
	// Nobody is listed who was not offered: a ref from anywhere else is not looked up (A66)
	host.floor_ui_act("floor_guest_add", list("ref" = REF(one_more)), owner)
	host.floor_ui_act("floor_bar_add", list("ref" = REF(stranger.mind)), owner)
	host.floor_ui_act("floor_guest_add", list("ref" = 5), owner)
	TEST_ASSERT(!(one_more in floor.guests) && !(stranger.mind in floor.barred), "The console listed someone it had not offered")

	// A deleted guest leaves the list
	var/datum/mind/doomed = invited[3]
	made_minds -= doomed
	qdel(doomed)
	TEST_ASSERT(!(doomed in floor.guests), "A deleted mind is still on the guest list (A36)")

/// A hand is hired only by their own yes, in time, and there are eight at most (L33, A80)
/datum/unit_test/voidcrew_outpost_floors/tenancy/hire

/datum/unit_test/voidcrew_outpost_floors/tenancy/hire/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/mob/living/owner = player(run_loc_floor_bottom_left, "tenancyhireowner")
	var/mob/living/rival = player(run_loc_floor_bottom_left, "tenancyhirerival")
	var/datum/outpost_floor/floor = let_floor(outpost, 1, owner)
	var/datum/outpost_floor/rival_floor = let_floor(outpost, 2, rival)
	if(!floor || !rival_floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/turf/deck = deck_tile(floor)
	owner.forceMove(deck)
	rival.forceMove(deck_tile(rival_floor))
	var/mob/living/steward = player(deck, "tenancyhiresteward")
	var/mob/living/first = player(deck, "tenancyhirefirst")
	var/mob/living/second = player(deck, "tenancyhiresecond")
	var/mob/living/third = player(deck, "tenancyhirethird")
	var/mob/living/away = player(run_loc_floor_bottom_left, "tenancyhireaway")
	host.residents |= steward.mind
	host.stewards |= steward.mind

	// An offer is only a question
	TEST_ASSERT(!floor.offer_hire(first, first), "Someone offered themselves work on a floor they do not run")
	TEST_ASSERT(!floor.offer_hire(away, owner), "Someone who is not at the outpost was offered work")
	TEST_ASSERT(floor.offer_hire(first, owner), "The owner could not offer work")
	TEST_ASSERT(!(first.mind in floor.hands), "Someone was hired without saying yes (A80)")
	TEST_ASSERT_NOTNULL(floor.tenancy_hire_pending(), "An offer of work is not waiting on its answer")
	TEST_ASSERT(!floor.offer_hire(second, owner), "A floor had two offers of work out at once")
	TEST_ASSERT(!floor.tenancy_hire_answer(second.mind, TRUE, owner), "Someone took an offer made to another")
	TEST_ASSERT(!rival_floor.offer_hire(first, rival), "Two floors had offers out to one person")

	// A no, and no asking again inside the minute, from any floor
	TEST_ASSERT(!floor.tenancy_hire_answer(first.mind, FALSE, owner), "A no hired someone")
	TEST_ASSERT_NULL(floor.tenancy_hire_pending(), "An answered offer is still out")
	TEST_ASSERT(!floor.offer_hire(first, owner), "Someone was offered work twice in a minute")
	TEST_ASSERT(!rival_floor.offer_hire(first, rival), "Another floor offered work inside the same minute")
	floor.tenancy_hire_asked[first.ckey] = world.time - 61 SECONDS // OUTPOST_FLOOR_HIRE_GAP is 1 MINUTES

	// A yes too late
	TEST_ASSERT(floor.offer_hire(first, steward), "A steward could not offer work after the minute")
	floor.tenancy_hire_until = world.time - 1 // OUTPOST_FLOOR_HIRE_ANSWER_TIME is 30 SECONDS
	TEST_ASSERT(!floor.tenancy_hire_answer(first.mind, TRUE, steward), "A yes after the offer lapsed hired someone")
	TEST_ASSERT(!(first.mind in floor.hands), "A lapsed offer hired someone")

	// A yes in time
	floor.tenancy_hire_asked -= first.ckey
	TEST_ASSERT(floor.offer_hire(first, owner), "The owner could not offer work again")
	TEST_ASSERT(floor.tenancy_hire_answer(first.mind, TRUE, owner), "A yes in time did not hire")
	TEST_ASSERT(first.mind in floor.hands, "A hired hand is not on the floor's hands")
	TEST_ASSERT(!floor.offer_hire(first, owner), "A hand was offered the work they have")

	// A yes is checked against everything again: barred while they thought about it
	TEST_ASSERT(floor.offer_hire(second, owner), "A second offer of work could not be made")
	floor.barred += second.mind
	TEST_ASSERT(!floor.tenancy_hire_answer(second.mind, TRUE, owner), "Someone barred while answering was hired")
	floor.barred -= second.mind

	// Eight hands and no ninth, when the offer is made and when it is answered
	TEST_ASSERT(floor.offer_hire(third, owner), "A third offer of work could not be made")
	while(length(floor.hands) < 8) // OUTPOST_FLOOR_HANDS_MAX
		floor.hands += loose_mind("Hand [length(floor.hands) + 1]")
	TEST_ASSERT(!floor.tenancy_hire_answer(third.mind, TRUE, owner), "A ninth hand was hired by a yes")
	floor.tenancy_hire_asked.Cut()
	TEST_ASSERT(!floor.offer_hire(third, owner), "A ninth hand was offered work")
	TEST_ASSERT_EQUAL(length(floor.hands), 8, "A floor has more than eight hands")
	var/list/data = host.floor_ui_data(owner)
	TEST_ASSERT_EQUAL(length(data["hands"]), 8, "The console was not sent eight hands")

	// Letting go
	TEST_ASSERT(!floor.let_go(first.mind, first), "A hand let themselves go at the floor's console")
	TEST_ASSERT(!floor.let_go(third.mind, owner), "Someone who is no hand was let go")
	host.floor_ui_act("floor_let_go", list("ref" = REF(first.mind)), steward)
	TEST_ASSERT(!(first.mind in floor.hands), "A steward could not let a hand go at the console")

/// The console's part for a floor: what each viewer is sent, and that every action checks who asks (build plan, section 5)
/datum/unit_test/voidcrew_outpost_floors/tenancy/console

/datum/unit_test/voidcrew_outpost_floors/tenancy/console/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/mob/living/owner = player(run_loc_floor_bottom_left, "tenancydeskowner")
	var/datum/outpost_floor/floor = let_floor(outpost, 3, owner)
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/turf/deck = deck_tile(floor)
	owner.forceMove(deck)
	var/mob/living/steward = player(deck, "tenancydesksteward")
	var/mob/living/stranger = player(deck, "tenancydeskstranger")
	host.residents |= steward.mind
	host.stewards |= steward.mind
	floor.guests += loose_mind("Desk Guest")
	floor.barred += loose_mind("Desk Barred")
	floor.hands += loose_mind("Desk Hand")
	floor.board_line = "Fresh bread."

	var/list/data = host.floor_ui_data(owner)
	TEST_ASSERT(data["is_floor"], "The console is not told it is on a floor")
	TEST_ASSERT_EQUAL(data["floor_number"], 3, "The console has the wrong floor number")
	TEST_ASSERT_EQUAL(data["floor_name"], "Floor 3", "The console has the wrong floor name")
	TEST_ASSERT_EQUAL(data["floor_entry"], "crew", "A new floor is not Crew only at the console") // OUTPOST_FLOOR_ENTRY_CREW
	TEST_ASSERT_EQUAL(data["board_line"], "Fresh bread.", "The console has the wrong board line")
	TEST_ASSERT_EQUAL(length(data["accents"]), 8, "The console is not offered eight colours")
	var/accent_known = FALSE
	for(var/list/accent as anything in data["accents"])
		TEST_ASSERT(istext(accent["id"]) && findtext(accent["hex"], "#") == 1, "A colour was sent without its id and hex")
		accent_known ||= accent["id"] == data["accent"]
	TEST_ASSERT(accent_known, "The floor's colour is not one of the eight the console is offered")
	TEST_ASSERT_EQUAL(length(data["guests"]) + length(data["barred"]) + length(data["hands"]), 3, "The owner is not sent the floor's lists")
	TEST_ASSERT(islist(data["floor_candidates"]), "The console is sent no candidates list")
	TEST_ASSERT(data["can_give_up"] && !data["can_take_over"], "The owner may not give up, or may take over, their own floor")
	TEST_ASSERT_NULL(data["hire_pending"], "An offer of work is out that nobody made")
	// The outposts' console already sends a `candidates` of its own: the floor's must not land on it
	TEST_ASSERT(!("candidates" in data), "The floor's data overwrites the console's own candidates")

	var/list/steward_data = host.floor_ui_data(steward)
	TEST_ASSERT_EQUAL(length(steward_data["guests"]), 1, "A steward is not sent the guest list")
	TEST_ASSERT(!steward_data["can_give_up"], "A steward may give up the floor")
	var/list/stranger_data = host.floor_ui_data(stranger)
	TEST_ASSERT_EQUAL(length(stranger_data["guests"]) + length(stranger_data["barred"]) + length(stranger_data["hands"]) + length(stranger_data["floor_candidates"]), 0, "A stranger is sent the floor's lists")
	TEST_ASSERT(!stranger_data["can_give_up"] && !stranger_data["can_take_over"], "A stranger may give up or take over the floor")

	// Actions: only floor_* are the floor's, and each checks who asks
	TEST_ASSERT(!host.floor_ui_act("rename", list("name" = "Not Mine"), owner), "The floor answered an action that is the console's own")
	TEST_ASSERT(host.floor_ui_act("floor_nonsense", list(), owner), "A floor_ action fell through to the console")
	host.floor_ui_act("floor_set_entry", list("entry" = "open"), stranger) // OUTPOST_FLOOR_ENTRY_OPEN
	TEST_ASSERT_EQUAL(floor.entry_policy, "crew", "A stranger changed who may come up")
	host.floor_ui_act("floor_set_entry", list("entry" = "everyone"), owner)
	TEST_ASSERT_EQUAL(floor.entry_policy, "crew", "A made-up setting was taken")
	host.floor_ui_act("floor_set_entry", list("entry" = "invited"), steward) // OUTPOST_FLOOR_ENTRY_INVITED
	TEST_ASSERT_EQUAL(floor.entry_policy, "invited", "A steward could not change who may come up")
	host.floor_ui_act("floor_set_name", list("name" = "Stewards Rest"), steward)
	host.floor_ui_act("floor_set_line", list("line" = "Under new management"), steward)
	host.floor_ui_act("floor_set_name", list("name" = "Squatters"), stranger)
	TEST_ASSERT_EQUAL(floor.floor_name, "Floor 3", "Somebody but the owner renamed the floor at the console")
	TEST_ASSERT_EQUAL(floor.board_line, "Fresh bread.", "Somebody but the owner set the board line at the console")
	host.floor_ui_act("floor_set_name", list("name" = "The Rusty Anchor"), owner)
	host.floor_ui_act("floor_set_line", list("line" = "Cold beer."), owner)
	TEST_ASSERT_EQUAL(floor.floor_name, "The Rusty Anchor", "The owner could not rename the floor at the console")
	TEST_ASSERT_EQUAL(floor.board_line, "Cold beer.", "The owner could not set the board line at the console")
	data = host.floor_ui_data(owner)
	TEST_ASSERT(data["floor_rename_wait"] > 0, "The console is not told the floor was just renamed")
	host.floor_ui_act("floor_set_accent", list("accent" = "violet"), stranger) // OUTPOST_FLOOR_ACCENT_VIOLET
	TEST_ASSERT(floor.accent != "violet", "A stranger picked the colour at the console")
	host.floor_ui_act("floor_set_accent", list("accent" = "violet"), steward)
	TEST_ASSERT_EQUAL(floor.accent, "violet", "A steward could not pick the colour at the console")

	// A floor has no docking: the console's own docking actions are shut there, whoever sends them
	for(var/shut in list("set_dock_mode", "approve_request", "deny_request", "ban_ship", "unban_ship", "revoke_approval", "install_ship_bay", "approve_bay_silo", "revoke_bay_silo"))
		TEST_ASSERT(host.floor_ui_act(shut, list("mode" = "lockdown", "ref" = REF(owner)), owner), "The docking action [shut] reaches a floor's host")
	TEST_ASSERT(!host.floor_ui_act("buy_upgrade", list("id" = "shop"), owner), "The floor shut an action a floor needs")

	// Giving up needs the owner's own confirmation, and nobody here can give it
	host.floor_ui_act("floor_give_up", list(), steward)
	host.floor_ui_act("floor_give_up", list(), owner)
	TEST_ASSERT_EQUAL(host.founder_ckey, owner.ckey, "A floor was given up with no confirmation")

	// A host with no floor is an outpost to the console
	var/obj/structure/overmap/dynamic/player_outpost/floor/bare = new(null)
	made_hosts += bare
	TEST_ASSERT_NULL(bare.floor_ui_data(owner), "A host with no floor has a floor section")
	TEST_ASSERT(!bare.floor_ui_act("floor_set_entry", list("entry" = "open"), owner), "A host with no floor handled a floor action")
