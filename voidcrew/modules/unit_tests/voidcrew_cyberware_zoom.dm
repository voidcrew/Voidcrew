/**
 * # Optics zoom (voidcrew/modules/cyberware/cyberware_zoom.dm, ware_line_zoom.dm)
 *
 * Every chrome optic zooms by tier, a zoomed bearer can't shoot, the zoom drops
 * whenever the eyes or the bearer stop working, and a click on the zoomed view
 * goes only to the cyberdeck seam. There is no client here, so tg's scope never
 * starts: these tests drive the optics' own half of a zoom (engage_zoom()) and
 * stand in a hand-made cursor catcher for the scope's.
 *
 * Unit-test files compile before voidcrew/_DEFINES/, so fork defines are
 * literals: TRAIT_CYBER_ZOOMED "cyber_zoomed", COMSIG_CYBERWARE_ZOOM_CLICK
 * "cyberware_zoom_click", COMPONENT_CYBERWARE_ZOOM_CLICK_HANDLED 1,
 * CYBERWARE_SCAN_SILHOUETTE 1 / _ITEMIZED 2, CYBERWARE_TIER_n n, and zone
 * permissions Public/Yellow/Advanced 0/1/2.
 */

/// Listens for zoomed clicks and stands in for an armed click-to-target ability.
/datum/zoom_click_probe
	/// What the last zoomed click handed over.
	var/atom/clicked
	/// How many zoom clicks arrived.
	var/zoom_clicks = 0
	/// Whether to claim the click, as a cyberdeck firing a hack would.
	var/handle = TRUE
	/// How many clicks reached us as a click intercept.
	var/intercepted = 0

/datum/zoom_click_probe/proc/on_zoom_click(mob/living/carbon/source, atom/target, list/modifiers)
	SIGNAL_HANDLER
	clicked = target
	zoom_clicks++
	return handle ? 1 : 0

/datum/zoom_click_probe/proc/InterceptClickOn(mob/user, params, atom/target)
	intercepted++
	return TRUE

/// The ladder: every optic zooms, carries the button and the scope, and reaches
/// what its tier says, never as far as binoculars (4).
/datum/unit_test/voidcrew_cyberware_zoom_ladder

/datum/unit_test/voidcrew_cyberware_zoom_ladder/Run()
	// optic => list(zoom, walk penalty)
	var/list/expected = list(
		/obj/item/organ/eyes/robotic/cyberware/spyglass = list(1, 1),
		/obj/item/organ/eyes/robotic/cyberware/prospector/street = list(1, 1),
		/obj/item/organ/eyes/robotic/cyberware/nightshade = list(1, 1),
		/obj/item/organ/eyes/robotic/cyberware/prospector = list(1.5, 0.5),
		/obj/item/organ/eyes/robotic/cyberware/deadeye = list(1.5, 0.5),
		/obj/item/organ/eyes/robotic/cyberware/longsight = list(2, 0),
		/obj/item/organ/eyes/robotic/cyberware/deadeye/milspec = list(2, 0),
		/obj/item/organ/eyes/robotic/cyberware/lookout = list(2.5, 0),
	)
	for(var/optic_type in subtypesof(/obj/item/organ/eyes/robotic/cyberware))
		var/obj/item/organ/eyes/robotic/cyberware/optics = allocate(optic_type)
		TEST_ASSERT(optics.optics_zoom > 0, "[optic_type] doesn't zoom")
		TEST_ASSERT(optics.optics_zoom < 4, "[optic_type] zooms as far as binoculars")
		TEST_ASSERT_EQUAL(optics.slot, ORGAN_SLOT_EYES, "[optic_type] left the eye slot, so it would stack with other optics")
		var/datum/component/scope/scope = optics.GetComponent(/datum/component/scope)
		TEST_ASSERT_NOTNULL(scope, "[optic_type] has no scope to zoom with")
		TEST_ASSERT_EQUAL(scope.range_modifier, optics.optics_zoom, "[optic_type]'s scope reaches a different distance from its zoom")
		TEST_ASSERT(locate(/datum/action/cooldown/cyberware/optics_zoom) in optics.actions, "[optic_type] has no zoom button")
		TEST_ASSERT(locate(/datum/action/cooldown/cyberware/chrome_read) in optics.actions, "[optic_type] lost its chrome read")
		TEST_ASSERT(istype(optics.actions[length(optics.actions)], /datum/action/cooldown/cyberware/optics_zoom), "[optic_type]'s zoom is not its last button")
		var/list/numbers = expected[optic_type]
		if(!numbers)
			continue
		TEST_ASSERT_EQUAL(optics.optics_zoom, numbers[1], "[optic_type] zooms the wrong distance")
		TEST_ASSERT_EQUAL(optics.zoom_walk_penalty, numbers[2], "[optic_type] has the wrong walk tax while zoomed")
	for(var/optic_type in expected)
		TEST_ASSERT(ispath(optic_type, /obj/item/organ/eyes/robotic/cyberware), "[optic_type] is no longer chrome optics")

/// The existing optics keep their numbers now they're vars, and the new models
/// carry theirs.
/datum/unit_test/voidcrew_cyberware_zoom_models

/datum/unit_test/voidcrew_cyberware_zoom_models/Run()
	// Chrome read: 7 tiles every 12 seconds unless the optics say otherwise.
	var/obj/item/organ/eyes/robotic/cyberware/nightshade/nightshade = allocate(/obj/item/organ/eyes/robotic/cyberware/nightshade)
	var/datum/action/cooldown/cyberware/chrome_read/stock_read = locate() in nightshade.actions
	TEST_ASSERT_EQUAL(nightshade.chrome_read_range, 7, "The stock chrome read range changed")
	TEST_ASSERT_EQUAL(stock_read.cooldown_time, 12 SECONDS, "The stock chrome read cooldown changed")

	// Deadeye, unchanged.
	var/obj/item/organ/eyes/robotic/cyberware/deadeye/deadeye = allocate(/obj/item/organ/eyes/robotic/cyberware/deadeye)
	TEST_ASSERT_EQUAL(deadeye.tag_range, 9, "Deadeye tag range changed")
	TEST_ASSERT_EQUAL(deadeye.tag_shots, 3, "Deadeye tracked shots changed")
	TEST_ASSERT_EQUAL(deadeye.tag_duration, 15 SECONDS, "Deadeye tag length changed")
	var/datum/action/cooldown/cyberware/deadeye_tag/deadeye_tag = locate() in deadeye.actions
	TEST_ASSERT_EQUAL(deadeye_tag.type, /datum/action/cooldown/cyberware/deadeye_tag, "The Deadeye carries the wrong tag")
	TEST_ASSERT_EQUAL(deadeye_tag.cooldown_time, 25 SECONDS, "Deadeye tag cooldown changed")

	// Marksman link: four shots, ten tiles, eighteen seconds, same tag length.
	var/obj/item/organ/eyes/robotic/cyberware/deadeye/milspec/marksman = allocate(/obj/item/organ/eyes/robotic/cyberware/deadeye/milspec)
	TEST_ASSERT_EQUAL(marksman.tag_range, 10, "Marksman tag range is not 10")
	TEST_ASSERT_EQUAL(marksman.tag_shots, 4, "Marksman tracked shots are not 4")
	TEST_ASSERT_EQUAL(marksman.tag_duration, 15 SECONDS, "Marksman tag length is not 15 s")
	var/datum/action/cooldown/cyberware/deadeye_tag/marksman/marksman_tag = locate() in marksman.actions
	TEST_ASSERT_NOTNULL(marksman_tag, "The Marksman link has no tag of its own")
	TEST_ASSERT_EQUAL(marksman_tag.cooldown_time, 18 SECONDS, "Marksman tag cooldown is not 18 s")
	check_chrome(marksman, 3, 4)

	// Prospector, unchanged; Assay optics shorter, slower and blind to caches.
	var/obj/item/organ/eyes/robotic/cyberware/prospector/prospector = allocate(/obj/item/organ/eyes/robotic/cyberware/prospector)
	TEST_ASSERT_EQUAL(prospector.pulse_range, 9, "Prospector pulse range changed")
	TEST_ASSERT(prospector.pulse_marks_caches, "The Prospector stopped flagging caches")
	var/datum/action/cooldown/cyberware/prospector_pulse/stock_pulse = locate() in prospector.actions
	TEST_ASSERT_EQUAL(stock_pulse.cooldown_time, 10 SECONDS, "Prospector pulse cooldown changed")
	var/obj/item/organ/eyes/robotic/cyberware/prospector/street/assay = allocate(/obj/item/organ/eyes/robotic/cyberware/prospector/street)
	TEST_ASSERT_EQUAL(assay.pulse_range, 5, "Assay pulse range is not 5")
	TEST_ASSERT(!assay.pulse_marks_caches, "Assay optics flag caches")
	var/datum/action/cooldown/cyberware/prospector_pulse/assay/assay_pulse = locate() in assay.actions
	TEST_ASSERT_NOTNULL(assay_pulse, "Assay optics have no pulse of their own")
	TEST_ASSERT_EQUAL(assay_pulse.cooldown_time, 15 SECONDS, "Assay pulse cooldown is not 15 s")
	TEST_ASSERT_EQUAL(assay.chrome_scan_resolution, 1, "Assay optics read at more than silhouette")
	check_chrome(assay, 1, 1)

	// The plain scout line.
	var/obj/item/organ/eyes/robotic/cyberware/spyglass/spyglass = allocate(/obj/item/organ/eyes/robotic/cyberware/spyglass)
	TEST_ASSERT_EQUAL(spyglass.chrome_scan_resolution, 1, "Spyglass optics read at more than silhouette")
	TEST_ASSERT_EQUAL(length(spyglass.actions), 2, "Spyglass optics should carry only the read and the zoom")
	check_chrome(spyglass, 1, 1)
	var/obj/item/organ/eyes/robotic/cyberware/longsight/longsight = allocate(/obj/item/organ/eyes/robotic/cyberware/longsight)
	TEST_ASSERT_EQUAL(longsight.chrome_scan_resolution, 2, "Longsight optics don't name what they read")
	TEST_ASSERT_EQUAL(longsight.chrome_read_range, 9, "Longsight read range is not 9")
	check_chrome(longsight, 2, 2)
	var/obj/item/organ/eyes/robotic/cyberware/lookout/lookout = allocate(/obj/item/organ/eyes/robotic/cyberware/lookout)
	TEST_ASSERT_EQUAL(lookout.chrome_scan_resolution, 2, "Lookout optics don't name what they read")
	TEST_ASSERT_EQUAL(lookout.chrome_read_range, 11, "Lookout read range is not 11")
	var/datum/action/cooldown/cyberware/chrome_read/lookout_read = locate() in lookout.actions
	TEST_ASSERT_EQUAL(lookout_read.cooldown_time, 8 SECONDS, "Lookout read cooldown is not 8 s")
	TEST_ASSERT_EQUAL(lookout.lighting_cutoff, LIGHTING_CUTOFF_MEDIUM, "Lookout optics lost their low-light")
	check_chrome(lookout, 3, 3)

/datum/unit_test/voidcrew_cyberware_zoom_models/proc/check_chrome(obj/item/organ/eyes/robotic/cyberware/optics, tier, load)
	var/datum/component/cyberware/chrome = optics.GetComponent(/datum/component/cyberware)
	TEST_ASSERT_EQUAL(chrome.tier, tier, "[optics.type] is the wrong tier")
	TEST_ASSERT_EQUAL(chrome.chrome_load, load, "[optics.type] carries the wrong neural load")

/// A zoom holds the trait and the walk tax, refuses guns, and lets go cleanly.
/datum/unit_test/voidcrew_cyberware_zoom_state

/datum/unit_test/voidcrew_cyberware_zoom_state/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/eyes/robotic/cyberware/spyglass/optics = allocate(/obj/item/organ/eyes/robotic/cyberware/spyglass)
	TEST_ASSERT(optics.Insert(bearer, special = TRUE), "Spyglass staging insert was refused")
	var/datum/action/cooldown/cyberware/optics_zoom/zoom = locate() in optics.actions
	TEST_ASSERT_EQUAL(zoom.owner, bearer, "The zoom button didn't come with the eyes")
	TEST_ASSERT(zoom.IsAvailable(), "Healthy installed optics can't zoom")

	// No client: the scope refuses, so the button can't zoom anyone here.
	TEST_ASSERT(!optics.start_zoom(), "A clientless bearer zoomed")
	TEST_ASSERT(!HAS_TRAIT(bearer, "cyber_zoomed"), "A refused zoom left the bearer zoomed")

	optics.engage_zoom(bearer)
	TEST_ASSERT(optics.is_zoomed() && HAS_TRAIT(bearer, "cyber_zoomed"), "Engaging the zoom didn't mark the bearer zoomed")
	TEST_ASSERT(zoom.is_action_active(null), "The zoom button doesn't show the zoom as on")
	TEST_ASSERT(bearer.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_zoom), "Cheap optics didn't slow their bearer while zoomed")

	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	TEST_ASSERT(bearer.put_in_active_hand(pistol), "Test fixture: the bearer couldn't hold the pistol")
	var/rounds = pistol.get_ammo()
	TEST_ASSERT(rounds > 0, "Test fixture: the pistol spawned empty")
	TEST_ASSERT(SEND_SIGNAL(bearer, COMSIG_MOB_TRYING_TO_FIRE_GUN, pistol, run_loc_floor_top_right, FALSE, null) & COMPONENT_CANCEL_GUN_FIRE, "A zoomed bearer's gun wasn't stopped")
	pistol.fire_gun(run_loc_floor_top_right, bearer, FALSE, null)
	TEST_ASSERT_EQUAL(pistol.get_ammo(), rounds, "A zoomed bearer fired a gun")

	optics.stop_zoom(bearer)
	TEST_ASSERT(!optics.is_zoomed() && !HAS_TRAIT(bearer, "cyber_zoomed"), "Stopping the zoom left the bearer zoomed")
	TEST_ASSERT(!bearer.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_zoom), "The walk tax outlived the zoom")
	TEST_ASSERT(!(SEND_SIGNAL(bearer, COMSIG_MOB_TRYING_TO_FIRE_GUN, pistol, run_loc_floor_top_right, FALSE, null) & COMPONENT_CANCEL_GUN_FIRE), "The gun block outlived the zoom")
	TEST_ASSERT(!zoom.is_action_active(null), "The zoom button still shows the zoom as on")

	// Scout optics zoom at full stride.
	var/mob/living/carbon/human/scout = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/eyes/robotic/cyberware/longsight/scout_optics = allocate(/obj/item/organ/eyes/robotic/cyberware/longsight)
	TEST_ASSERT(scout_optics.Insert(scout, special = TRUE), "Longsight staging insert was refused")
	scout_optics.engage_zoom(scout)
	TEST_ASSERT(!scout.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_zoom), "Scout optics slowed their bearer while zoomed")
	scout_optics.stop_zoom(scout)

/// Everything that should end a zoom does.
/datum/unit_test/voidcrew_cyberware_zoom_drops

/datum/unit_test/voidcrew_cyberware_zoom_drops/Run()
	var/obj/item/organ/eyes/robotic/cyberware/optics = zoomed()
	var/datum/component/cyberware/chrome = optics.GetComponent(/datum/component/cyberware)
	var/datum/action/cooldown/cyberware/optics_zoom/zoom = locate() in optics.actions
	chrome.start_emp_reboot()
	check_dropped(optics, "an EMP")
	TEST_ASSERT(!zoom.IsAvailable(), "EMP-scrambled optics can still zoom")
	chrome.tune_up()
	TEST_ASSERT(zoom.IsAvailable(), "Rebooted optics can't zoom again")

	optics = zoomed()
	chrome = optics.GetComponent(/datum/component/cyberware)
	chrome.set_browned_out(TRUE)
	check_dropped(optics, "a brownout")
	chrome.set_browned_out(FALSE)

	optics = zoomed()
	chrome = optics.GetComponent(/datum/component/cyberware)
	optics.set_organ_damage(optics.maxHealth)
	chrome.update_failing() // the bearer's life tick, which settles damage failure
	check_dropped(optics, "the eyes failing")

	optics = zoomed()
	optics.owner.flash_act(1)
	check_dropped(optics, "a flash")

	optics = zoomed()
	optics.owner.become_blind("voidcrew_zoom_test")
	check_dropped(optics, "going blind")

	optics = zoomed()
	optics.owner.Stun(2 SECONDS)
	check_dropped(optics, "a stun")

	optics = zoomed()
	optics.owner.Knockdown(2 SECONDS)
	check_dropped(optics, "a knockdown")

	optics = zoomed()
	optics.owner.Paralyze(2 SECONDS)
	check_dropped(optics, "paralysis")

	optics = zoomed()
	optics.owner.death()
	check_dropped(optics, "death")

	optics = zoomed()
	var/mob/living/carbon/human/bearer = optics.owner
	optics.Remove(bearer, special = TRUE)
	TEST_ASSERT(!HAS_TRAIT(bearer, "cyber_zoomed"), "Pulling the optics out left their bearer zoomed")
	TEST_ASSERT(!bearer.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_zoom), "Pulling the optics out left the walk tax on")

/// A fresh bearer, zoomed through a fresh pair of Spyglass optics.
/datum/unit_test/voidcrew_cyberware_zoom_drops/proc/zoomed()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/eyes/robotic/cyberware/spyglass/optics = allocate(/obj/item/organ/eyes/robotic/cyberware/spyglass)
	TEST_ASSERT(optics.Insert(bearer, special = TRUE), "Spyglass staging insert was refused")
	optics.engage_zoom(bearer)
	TEST_ASSERT(optics.is_zoomed(), "Test fixture: the zoom didn't engage")
	return optics

/datum/unit_test/voidcrew_cyberware_zoom_drops/proc/check_dropped(obj/item/organ/eyes/robotic/cyberware/optics, cause)
	var/mob/living/carbon/human/bearer = optics.owner
	TEST_ASSERT(!optics.is_zoomed() && !HAS_TRAIT(bearer, "cyber_zoomed"), "The zoom survived [cause]")
	TEST_ASSERT(!bearer.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_zoom), "The walk tax survived [cause]")
	TEST_ASSERT(!(SEND_SIGNAL(bearer, COMSIG_MOB_TRYING_TO_FIRE_GUN, null, null, FALSE, null) & COMPONENT_CANCEL_GUN_FIRE), "The gun block survived [cause]")

/// The cyberdeck seam: a zoomed click goes to COMSIG_CYBERWARE_ZOOM_CLICK with
/// what is under the cursor, never to a click intercept, and only while zoomed.
/datum/unit_test/voidcrew_cyberware_zoom_click

/datum/unit_test/voidcrew_cyberware_zoom_click/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/far_body = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
	var/obj/item/organ/eyes/robotic/cyberware/lookout/optics = allocate(/obj/item/organ/eyes/robotic/cyberware/lookout)
	TEST_ASSERT(optics.Insert(bearer, special = TRUE), "Lookout staging insert was refused")

	// Stand in for the scope's cursor catcher, pointed at the far body.
	var/datum/component/scope/scope = optics.GetComponent(/datum/component/scope)
	var/atom/movable/screen/fullscreen/cursor_catcher/scope/catcher = new
	catcher.owner = bearer
	catcher.given_turf = get_turf(far_body)
	scope.tracker = catcher
	optics.engage_zoom(bearer)

	var/datum/zoom_click_probe/probe = allocate(/datum/zoom_click_probe)
	probe.RegisterSignal(bearer, "cyberware_zoom_click", TYPE_PROC_REF(/datum/zoom_click_probe, on_zoom_click))
	bearer.click_intercept = probe

	bearer.ClickOn(catcher, "")
	TEST_ASSERT_EQUAL(probe.clicked, far_body, "A zoomed click didn't hand over the body under the cursor")
	TEST_ASSERT_EQUAL(probe.intercepted, 0, "An armed click intercept saw a zoomed click")

	// Unclaimed, the click still goes nowhere else.
	probe.handle = FALSE
	probe.clicked = null
	bearer.next_click = 0
	bearer.ClickOn(catcher, "")
	TEST_ASSERT_EQUAL(probe.zoom_clicks, 2, "An unclaimed zoomed click never reached the seam")
	TEST_ASSERT_EQUAL(probe.intercepted, 0, "An unclaimed zoomed click fell through to a click intercept")

	// Nothing on the tile: the tile itself.
	var/turf/empty_tile = locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y + 1, run_loc_floor_bottom_left.z)
	catcher.given_turf = empty_tile
	bearer.next_click = 0
	bearer.ClickOn(catcher, "")
	TEST_ASSERT_EQUAL(probe.clicked, empty_tile, "A zoomed click on an empty tile didn't hand over the tile")

	// Out of the zoom, clicks are ordinary again.
	optics.stop_zoom(bearer)
	bearer.next_click = 0
	bearer.ClickOn(catcher, "")
	TEST_ASSERT_EQUAL(probe.zoom_clicks, 3, "A click after the zoom ended still went to the seam")
	TEST_ASSERT_EQUAL(probe.intercepted, 1, "Clicks stayed swallowed after the zoom ended")

	bearer.click_intercept = null
	scope.tracker = null
	qdel(catcher)

/// The zoom button sits on the chrome wheel, and swapping optics with a
/// different number of buttons never moves the ear chrome beside them.
/datum/unit_test/voidcrew_cyberware_zoom_wheel

/datum/unit_test/voidcrew_cyberware_zoom_wheel/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/eyes/robotic/cyberware/spyglass/cheap = allocate(/obj/item/organ/eyes/robotic/cyberware/spyglass)
	TEST_ASSERT(cheap.Insert(bearer, special = TRUE), "Spyglass staging insert was refused")
	var/obj/item/organ/cyberimp/cyberware/doppler/ears = allocate(/obj/item/organ/cyberimp/cyberware/doppler)
	TEST_ASSERT(ears.Insert(bearer, special = TRUE), "Doppler staging insert was refused")
	var/datum/action/cheap_zoom = locate(/datum/action/cooldown/cyberware/optics_zoom) in cheap.actions
	var/datum/action/sonar = locate(/datum/action/item_action/organ_action/toggle) in ears.actions
	TEST_ASSERT(cheap_zoom && sonar, "A staged organ is missing its button")

	var/list/abilities = get_chrome_wheel_actions(bearer)
	TEST_ASSERT(cheap_zoom in abilities, "The zoom button isn't on the chrome wheel")
	var/list/positions = chrome_wheel_layout(abilities)
	var/list/ears_at = positions[sonar]

	// Optics with an ability of their own: three eye buttons instead of two.
	var/obj/item/organ/eyes/robotic/cyberware/deadeye/milspec/link = allocate(/obj/item/organ/eyes/robotic/cyberware/deadeye/milspec)
	TEST_ASSERT(link.Insert(bearer, special = TRUE), "Marksman link staging insert was refused")
	abilities = get_chrome_wheel_actions(bearer)
	TEST_ASSERT(!(cheap_zoom in abilities), "The pulled optics' zoom stayed on the wheel")
	TEST_ASSERT(locate(/datum/action/cooldown/cyberware/optics_zoom) in abilities, "The new optics' zoom isn't on the wheel")
	positions = chrome_wheel_layout(abilities)
	var/list/ears_now = positions[sonar]
	TEST_ASSERT(ears_at[1] == ears_now[1] && ears_at[2] == ears_now[2], "Swapping optics moved the ear chrome on the wheel")

/// Shelf prices and gates, half-list trade-ins, and cradle quotes.
/datum/unit_test/voidcrew_cyberware_zoom_catalog

/datum/unit_test/voidcrew_cyberware_zoom_catalog/Run()
	// SKU => list(item, credits, vouchers, zone permission)
	var/list/skus = list(
		/datum/shop_sku/ripperdoc/spyglass = list(/obj/item/organ/eyes/robotic/cyberware/spyglass, 400, 0, 0),
		/datum/shop_sku/ripperdoc/assay_optics = list(/obj/item/organ/eyes/robotic/cyberware/prospector/street, 900, 0, 0),
		/datum/shop_sku/ripperdoc/longsight = list(/obj/item/organ/eyes/robotic/cyberware/longsight, 2400, 0, 1),
		/datum/shop_sku/ripperdoc/deadeye_milspec = list(/obj/item/organ/eyes/robotic/cyberware/deadeye/milspec, 0, 3, 2),
		/datum/shop_sku/ripperdoc/lookout = list(/obj/item/organ/eyes/robotic/cyberware/lookout, 0, 3, 2),
	)
	build_cyberware_price_index()
	for(var/datum/shop_sku/sku_type as anything in skus)
		var/list/row = skus[sku_type]
		TEST_ASSERT_EQUAL(initial(sku_type.item_path), row[1], "[sku_type] sells the wrong optics")
		TEST_ASSERT_EQUAL(initial(sku_type.price_credits), row[2], "[sku_type] has the wrong credit price")
		TEST_ASSERT_EQUAL(initial(sku_type.price_vouchers), row[3], "[sku_type] has the wrong voucher price")
		TEST_ASSERT_EQUAL(initial(sku_type.zone_permission), row[4], "[sku_type] has the wrong reputation gate")
		var/obj/item/organ/optics = allocate(row[1])
		var/list/quote = get_cyberware_price(optics)
		TEST_ASSERT(quote && (quote["credits"] > 0 || quote["vouchers"] > 0), "The cradle quotes no price for [row[1]]")

	// Trade-in => the SKU it pays half of.
	var/list/trade_ins = list(
		/datum/shop_buyback/ripperdoc/spyglass = /datum/shop_sku/ripperdoc/spyglass,
		/datum/shop_buyback/ripperdoc/assay_optics = /datum/shop_sku/ripperdoc/assay_optics,
		/datum/shop_buyback/ripperdoc/longsight = /datum/shop_sku/ripperdoc/longsight,
		/datum/shop_buyback/ripperdoc/spyglass/street_doc = /datum/shop_sku/ripperdoc/spyglass,
		/datum/shop_buyback/ripperdoc/assay_optics/street_doc = /datum/shop_sku/ripperdoc/assay_optics,
		/datum/shop_buyback/ripperdoc/longsight/street_doc = /datum/shop_sku/ripperdoc/longsight,
	)
	for(var/buyback_type in trade_ins)
		var/datum/shop_buyback/ledger = allocate(buyback_type)
		var/datum/shop_sku/sku_type = trade_ins[buyback_type]
		TEST_ASSERT_EQUAL(ledger.item_path, initial(sku_type.item_path), "[buyback_type] buys something its shelf doesn't sell")
		TEST_ASSERT(!ledger.match_subtypes, "[buyback_type] buys subtypes too")
		TEST_ASSERT_EQUAL(ledger.pay_credits * 2, initial(sku_type.price_credits), "[buyback_type] doesn't pay half list")
		TEST_ASSERT(!ledger.pay_vouchers, "[buyback_type] pays vouchers")
