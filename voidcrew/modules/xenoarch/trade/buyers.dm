/**
 * # Outpost buyers for dig finds
 *
 * Barnaby at Halcyon, Boffin at the Quartermain's Skunkworks and Vex at the Undertow buy what
 * comes out of the old dig sites. They are the outposts' own traders: this file gives each one a
 * buyer's voice (/datum/xenoarch_buyer) and two rows on their wanted ledger, so a find sells from
 * the same Sell tab as everything else they buy.
 *
 * - Large finds are machinery, so the stock ledger (which only takes inventory items) can't hold
 *   them. /datum/shop_buyback/xenoarch_find takes the find the seller is pulling, loose or in a
 *   shut crate, once it is at the counter. The trader looks it over while the seller waits, then
 *   pays artifact_sale_value() into the account every other sale pays (get_shop_buyback_account()),
 *   prints a receipt and says what they made of it. The sale is final: nothing is quoted, so a
 *   label can't be tried out on the buyer.
 * - Only finds stamped as dug sell. Vex pays a voucher on top for an extreme main effect.
 * - Curios (/datum/shop_buyback/xenoarch_curio) are ordinary items marked as dug finds with
 *   xenoarch_mark_curio(); Barnaby and Boffin take them, and only Boffin takes strange objects.
 * - Each buyer takes XENOARCH_FIND_DEMAND large finds and XENOARCH_CURIO_DEMAND curios at a time,
 *   topped up by the convoy like any other ledger row (shop.dm convoy_restock()).
 * - A buyer notices a find being hauled up to the counter and says so, once per find.
 * - Selling earns no reputation; that comes from jobs (trader_favor.dm).
 */

/// Large finds each buyer takes before the next convoy
#define XENOARCH_FIND_DEMAND 3
/// Curios each buyer takes before the next convoy
#define XENOARCH_CURIO_DEMAND 6
/// How far from the trader a hauled find may be and still count as at the counter
#define XENOARCH_COUNTER_REACH 3
/// How long the trader looks a find over before paying
#define XENOARCH_INSPECT_TIME (2.5 SECONDS)
/// Least time between the starts of two inspections, so the Sell button can't be used to make the trader spam
#define XENOARCH_INSPECT_COOLDOWN (4 SECONDS)
/// How far away a trader notices a find being hauled in
#define XENOARCH_NOTICE_RANGE 4
/// Least time between two "what have you got there" remarks
#define XENOARCH_NOTICE_COOLDOWN (30 SECONDS)
/// How many finds a trader remembers having remarked on
#define XENOARCH_NOTICE_MEMORY 20

// Line keys for /datum/xenoarch_buyer/var/lines
/// Spoken when a find is hauled up
#define XENOARCH_LINE_NOTICE "notice"
/// Emotes while looking over a loose find; %THING% is the find
#define XENOARCH_LINE_INSPECT "inspect"
/// Emotes while looking into a crate; %THING% is the crate
#define XENOARCH_LINE_INSPECT_CRATED "inspect_crated"
/// Spoken while looking over a find that came out of the rock cracked
#define XENOARCH_LINE_CRACKED "cracked"
/// Spoken while looking over a find that has been drained
#define XENOARCH_LINE_TAPPED "tapped"
/// Spoken on paying for a find labelled right on every line
#define XENOARCH_LINE_PERFECT "perfect"
/// Spoken on paying for a find labelled mostly right
#define XENOARCH_LINE_CLOSE "close"
/// Spoken on paying for a find labelled mostly wrong
#define XENOARCH_LINE_WRONG "wrong"
/// Spoken on paying for a find with no label
#define XENOARCH_LINE_BLANK "blank"
/// Spoken on paying for a find with an extreme main effect
#define XENOARCH_LINE_LIVE "live"
/// Spoken when the seller walks off mid-inspection
#define XENOARCH_LINE_WALKED "walked"

// =========================================================================
// HAULING
// =========================================================================

/// The large find in `thing`: the artifact itself, or the first artifact in a shut crate. Null otherwise.
/proc/xenoarch_find_in(atom/movable/thing)
	if(istype(thing, /obj/machinery/artifact))
		return thing
	if(istype(thing, /obj/structure/closet))
		var/obj/structure/closet/box = thing
		if(!box.opened)
			return locate(/obj/machinery/artifact) in box.contents
	return null

/// Every large find `user` is hauling: the artifact they pull, or those in the shut crate they pull.
/proc/xenoarch_hauled_finds(mob/living/user)
	. = list()
	var/atom/movable/hauled = user?.pulling
	if(istype(hauled, /obj/machinery/artifact))
		. += hauled
	else if(istype(hauled, /obj/structure/closet))
		var/obj/structure/closet/box = hauled
		if(!box.opened)
			for(var/obj/machinery/artifact/find in box.contents)
				. += find

/// What a hauled find rides in: its crate, or the find itself when loose.
/proc/xenoarch_find_holder(obj/machinery/artifact/find)
	if(!find)
		return null
	return isturf(find.loc) ? find : find.loc

/// "1,125 cr"
/proc/xenoarch_credits_text(amount)
	var/digits = num2text(round(abs(amount)), 12)
	var/grouped = ""
	while(length(digits) > 3)
		grouped = ",[copytext(digits, -3)][grouped]"
		digits = copytext(digits, 1, -3)
	return "[amount < 0 ? "-" : ""][digits][grouped] cr"

// =========================================================================
// THE BUYERS
// =========================================================================

/**
 * # Dig-find buyer
 *
 * The buying side of one outpost trader: their voice for finds, what they take, and how their
 * receipt reads. One per shop, made by the shop (see /datum/outpost_shop/New below).
 */
/datum/xenoarch_buyer
	/// The shop this buyer works for
	var/datum/outpost_shop/shop
	/// Vouchers paid on top of credits for a find whose main effect is extreme
	var/extreme_vouchers = 0
	/// Buys curios at all
	var/buys_curios = TRUE
	/// Takes tg's strange objects among the curios
	var/takes_strange_objects = FALSE
	/// Large-find ledger row: name, description and picture
	var/find_name = "dig pieces"
	var/find_desc = "Large finds out of the old dig sites."
	var/find_icon = 'voidcrew/modules/xenoarch/icons/artifacts.dmi'
	var/find_icon_state = "idol"
	/// Curio ledger row: name, description and picture
	var/curio_name = "curios"
	var/curio_desc = "Small finds out of the old dig sites."
	var/curio_icon = 'icons/obj/mining.dmi'
	var/curio_icon_state = "skull"
	/// Receipt heading, subheading, sign-off, hand, ink and paper stamp
	var/receipt_title = "RECEIPT"
	var/receipt_subtitle
	var/receipt_signoff
	var/receipt_font = PEN_FONT
	var/receipt_ink = "#202020"
	var/receipt_stamp
	/// Heard while the buyer looks a find over
	var/inspect_sound = 'sound/items/handling/paper_pickup.ogg'
	/// Speech and emotes, by XENOARCH_LINE_* key
	var/list/lines = list()
	/// Extra idle chatter added to the shop's own
	var/list/idle_lines = list()
	/// Serials already remarked on, oldest first
	var/list/noticed = list()
	/// The find being looked over right now
	var/datum/weakref/inspecting
	/// When the buyer may next remark on a hauled find
	COOLDOWN_DECLARE(notice_cooldown)
	/// When the buyer may next start looking a find over
	COOLDOWN_DECLARE(inspect_cooldown)

/datum/xenoarch_buyer/New(datum/outpost_shop/shop)
	. = ..()
	src.shop = shop

/datum/xenoarch_buyer/Destroy()
	shop = null
	inspecting = null
	return ..()

/// Ledger rows this buyer adds to their shop.
/datum/xenoarch_buyer/proc/ledger_types()
	. = list(/datum/shop_buyback/xenoarch_find)
	if(buys_curios)
		. += /datum/shop_buyback/xenoarch_curio

/// The trader at the counter, if the interior has one.
/datum/xenoarch_buyer/proc/trader()
	return shop?.trader_npc

/// Looking a find over right now (a live find, not one sold or lost meanwhile), or only just done with one.
/datum/xenoarch_buyer/proc/is_busy()
	var/obj/machinery/artifact/find = inspecting?.resolve()
	if(QDELETED(find))
		inspecting = null
		return !COOLDOWN_FINISHED(src, inspect_cooldown)
	return TRUE

/// Vouchers this buyer adds for `find`.
/datum/xenoarch_buyer/proc/vouchers_for(obj/machinery/artifact/find)
	if(extreme_vouchers > 0 && find?.main_effect?.tier == ARTIFACT_TIER_EXTREME)
		return extreme_vouchers
	return 0

/// A random line for `key`, or null.
/datum/xenoarch_buyer/proc/line(key)
	var/list/options = lines[key]
	return length(options) ? pick(options) : null

/// The trader says `text`, and holds their other chatter back for a moment.
/datum/xenoarch_buyer/proc/speak(mob/living/basic/outpost_trader/vendor, text)
	if(QDELETED(vendor) || !text)
		return
	COOLDOWN_START(vendor, speak_cooldown, 3 SECONDS)
	vendor.say(text)

/// The trader starts looking over `find`, riding in `holder` (the find itself, or its crate).
/datum/xenoarch_buyer/proc/begin_inspection(mob/living/basic/outpost_trader/vendor, obj/machinery/artifact/find, atom/movable/holder)
	if(QDELETED(vendor))
		return
	var/emote = line(holder == find ? XENOARCH_LINE_INSPECT : XENOARCH_LINE_INSPECT_CRATED)
	if(emote)
		vendor.manual_emote(replacetext(emote, "%THING%", "\the [holder]"))
	if(holder != find)
		playsound(holder, 'sound/machines/crate/crate_open.ogg', 20, TRUE)
	if(inspect_sound)
		playsound(vendor, inspect_sound, 30, TRUE)
	// Cracks and a drained feel are plain to anyone looking; said while looking, not as a verdict.
	if(find.damaged)
		speak(vendor, line(XENOARCH_LINE_CRACKED))
	else if(find.harvests_taken() > 0)
		speak(vendor, line(XENOARCH_LINE_TAPPED))

/// What the trader says as they pay for `find`. Only said once the find is theirs.
/datum/xenoarch_buyer/proc/closing_line(obj/machinery/artifact/find)
	if(find.main_effect?.tier == ARTIFACT_TIER_EXTREME)
		return line(XENOARCH_LINE_LIVE)
	if(!find.label)
		return line(XENOARCH_LINE_BLANK)
	var/accuracy = round(find.label_accuracy(), 0.01)
	if(accuracy >= 1)
		return line(XENOARCH_LINE_PERFECT)
	if(accuracy >= ARTIFACT_LABEL_ACCURACY_FLOOR)
		return line(XENOARCH_LINE_CLOSE)
	return line(XENOARCH_LINE_WRONG)

/**
 * Remarks on a find being hauled up to the counter, once per find and not too often. Runs on the
 * trader's life tick. Only finds a player is pulling count: that is someone showing it off.
 */
/datum/xenoarch_buyer/proc/look_around(mob/living/basic/outpost_trader/vendor)
	if(!COOLDOWN_FINISHED(src, notice_cooldown) || is_busy() || !isturf(vendor.loc))
		return
	for(var/atom/movable/thing in range(XENOARCH_NOTICE_RANGE, vendor))
		var/mob/living/hauler = thing.pulledby
		if(!hauler?.client)
			continue
		var/obj/machinery/artifact/find = xenoarch_find_in(thing)
		if(!find?.is_dug() || (find.serial in noticed))
			continue
		noticed += find.serial
		if(length(noticed) > XENOARCH_NOTICE_MEMORY)
			noticed.Cut(1, 2)
		COOLDOWN_START(src, notice_cooldown, XENOARCH_NOTICE_COOLDOWN)
		speak(vendor, line(XENOARCH_LINE_NOTICE))
		return

/// The receipt's body: the facts of one sale, in this buyer's hand.
/datum/xenoarch_buyer/proc/receipt_text(list/sale)
	var/list/parts = list()
	parts += "<center><b>[receipt_title]</b>[receipt_subtitle ? "<br><i>[receipt_subtitle]</i>" : ""]</center><hr>"
	parts += "Bought of <b>[sale["seller"]]</b>, [sale["time"]].<br>"
	parts += "One [sale["find"]], field tag <b>[sale["serial"]]</b>.<br>"
	parts += sale["label"] ? "The tag on it says: <i>[sale["label"]]</i>.<br>" : "No label on it.<br>"
	if(sale["condition"])
		parts += "Condition: [sale["condition"]].<br>"
	parts += "<br>Paid <b>[sale["price"]]</b> to [sale["account"]].<br>"
	if(sale["vouchers"])
		parts += "Also handed over: [sale["vouchers"]] trade voucher[sale["vouchers"] > 1 ? "s" : ""].<br>"
	if(receipt_signoff)
		parts += "<hr><i>[receipt_signoff]</i>"
	return parts.Join()

/// The facts of a sale, taken before the find is gone.
/datum/xenoarch_buyer/proc/sale_record(obj/machinery/artifact/find, mob/living/seller, price, vouchers, datum/bank_account/account)
	var/list/condition = list()
	if(find.damaged)
		condition += "cracked"
	if(find.harvests_taken() > 0)
		condition += "drained"
	var/label_text
	if(find.label)
		label_text = "[find.label.effect_name || "?"] / [find.label.trigger_name || "?"] / [find.label.second_name || ARTIFACT_LABEL_NONE]"
	return list(
		"seller" = seller?.real_name || "a stranger",
		"time" = station_time_timestamp("hh:mm"),
		"find" = find.name,
		"serial" = find.serial,
		"label" = label_text,
		"label_off" = !!find.label && round(find.label_accuracy(), 0.01) < 1,
		"condition" = length(condition) ? condition.Join(", ") : null,
		"price" = xenoarch_credits_text(price),
		"vouchers" = vouchers,
		"account" = account?.account_holder || "the seller",
	)

// ----- Barnaby: Waystation Halcyon, green -----

/datum/xenoarch_buyer/barnaby
	find_name = "dig pieces"
	find_desc = "Anything big and old out of the cliffs. Barnaby pays fair and keeps the nice ones in the back."
	find_icon_state = "idol"
	curio_name = "curios"
	curio_desc = "Fossils, pots, little figures. The gift shop does well out of them."
	curio_icon = 'icons/obj/mining.dmi'
	curio_icon_state = "skull"
	receipt_title = "WAYSTATION HALCYON"
	receipt_subtitle = "General Store"
	receipt_signoff = "With thanks, B."
	receipt_font = FOUNTAIN_PEN_FONT
	receipt_ink = "#24305e"
	receipt_stamp = "stamp-qm"
	inspect_sound = 'sound/items/handling/book_pickup.ogg'
	lines = list(
		XENOARCH_LINE_NOTICE = list(
			"Goodness, what have you dragged in? Bring it round, dear.",
			"Oh, that's come out of the ground, hasn't it. Let's have a look.",
			"Mind the floor with that. It's only just been mopped.",
		),
		XENOARCH_LINE_INSPECT = list(
			"pushes his reading glasses up his nose and leans over %THING%.",
			"peers at %THING% over his glasses, humming.",
		),
		XENOARCH_LINE_INSPECT_CRATED = list(
			"lifts the lid of %THING% and peers inside, glasses on the end of his nose.",
			"props open %THING% with one hand and has a good long look.",
		),
		XENOARCH_LINE_CRACKED = list(
			"Oh dear. Cracked right down the side.",
			"Somebody's been rough with this one.",
		),
		XENOARCH_LINE_TAPPED = list(
			"Feels tired, this one. Somebody's had a go at it.",
			"Hm. Not as lively as it ought to be.",
		),
		XENOARCH_LINE_PERFECT = list(
			"Labelled proper and everything. You've done your homework, dear.",
			"Exactly what it says on the tag. Lovely.",
		),
		XENOARCH_LINE_CLOSE = list(
			"Near enough what it says on the tag. I'll not quibble.",
			"Mostly right, that label. Mostly.",
		),
		XENOARCH_LINE_WRONG = list(
			"I'm not sure this label's been anywhere near this thing, dear.",
			"Whoever wrote this tag was guessing. I'll pay for the rock.",
		),
		XENOARCH_LINE_BLANK = list(
			"No label? Then I'm buying a mystery, and mysteries come cheap.",
			"Not a word on it about what it does. I'll take it on faith, at a faith price.",
		),
		XENOARCH_LINE_LIVE = list(
			"Goodness. This one's very much awake in there. I'll be glad when the courier takes it.",
			"Oh my. I'll be keeping this one well away from the biscuit tin.",
		),
		XENOARCH_LINE_WALKED = list(
			"Oh! Never mind, then.",
			"Changed your mind? That's all right, dear.",
		),
	)
	idle_lines = list(
		"Folk keep digging funny old things out of the cliffs. I'll buy them, if they don't hum too loud.",
		"Had a lad bring in a stone that whistled. Paid him for it. It's in the back. It still whistles.",
	)

// ----- Boffin: the Skunkworks, Quartermain Depot, yellow -----

/datum/xenoarch_buyer/boffin
	takes_strange_objects = TRUE
	find_name = "alien artifacts"
	find_desc = "Large finds out of the old dig sites. Boffin likes them catalogued and in one piece."
	find_icon_state = "terminal"
	curio_name = "curios and oddities"
	curio_desc = "Small dig finds, and the strange objects nobody can explain. Especially those."
	curio_icon = 'icons/obj/devices/artefacts.dmi'
	curio_icon_state = "prototype3"
	receipt_title = "THE SKUNKWORKS"
	receipt_subtitle = "Specimen intake"
	receipt_signoff = "Received for bench testing. Boffin, QA."
	receipt_font = PEN_FONT
	receipt_ink = "#1d3b6e"
	receipt_stamp = "stamp-rd"
	inspect_sound = 'sound/machines/scanner/scanner.ogg'
	lines = list(
		XENOARCH_LINE_NOTICE = list(
			"Oh. Oh, that's not from around here. Bring it closer. No, not THAT close.",
			"Is that a dig piece? Wheel it over, wheel it over.",
			"I can hear that from here. Lovely.",
		),
		XENOARCH_LINE_INSPECT = list(
			"waves his multitool over %THING%, squinting at the readout.",
			"taps %THING% with his multitool and listens.",
		),
		XENOARCH_LINE_INSPECT_CRATED = list(
			"pries up the lid of %THING% and pokes his multitool inside.",
			"leans into %THING% with his multitool held out like a divining rod.",
		),
		XENOARCH_LINE_CRACKED = list(
			"Cracked straight through. Somebody dug this out with a shovel and a prayer.",
			"Fracture lines. I can see them. I can always see them.",
		),
		XENOARCH_LINE_TAPPED = list(
			"Someone's been siphoning this. It's running on fumes.",
			"Drained. Partly. The hum's a semitone flat.",
		),
		XENOARCH_LINE_PERFECT = list(
			"Label checks out on every line. Somebody on your crew owns a notebook. Keep them.",
			"Correct on every count. I'm almost disappointed. Nothing left for me to discover.",
		),
		XENOARCH_LINE_CLOSE = list(
			"Label's close. I'll fix the rest in pencil.",
			"Mostly right. The rest is what we in the trade call a learning opportunity.",
		),
		XENOARCH_LINE_WRONG = list(
			"Your label and my multitool disagree. My multitool is right.",
			"This label is fiction. Good fiction. Still fiction.",
		),
		XENOARCH_LINE_BLANK = list(
			"No label. I love a blind test, but I don't pay for one.",
			"Unlabelled. So I'm paying for a rock and a hunch.",
		),
		XENOARCH_LINE_LIVE = list(
			"Oh, this is a LIVE one. Nobody touch anything. Especially me.",
			"That's the real thing. I'm going to need a bigger bench.",
		),
		XENOARCH_LINE_WALKED = list(
			"Hey! I was measuring that!",
			"Fine. Take your rock. I'll measure the dent it left.",
		),
	)
	idle_lines = list(
		"Old dig pieces! Alien, ancient, occasionally ticking. My three favourite words.",
		"Bring me something out of the deep rock. I promise to only lick it once.",
	)

// A lab intake sheet, with a pencil note when the label needed fixing.
/datum/xenoarch_buyer/boffin/receipt_text(list/sale)
	var/list/parts = list()
	parts += "<center><b>[receipt_title]</b><br><i>[receipt_subtitle]</i></center><hr>"
	parts += "Specimen: <b>[sale["serial"]]</b> ([sale["find"]])<br>"
	parts += "From: [sale["seller"]], [sale["time"]]<br>"
	parts += "Label as received: [sale["label"] ? "<i>[sale["label"]]</i>[sale["label_off"] ? " (corrected in pencil)" : ""]" : "none"]<br>"
	parts += "Condition: [sale["condition"] || "intact"]<br>"
	parts += "Paid: <b>[sale["price"]]</b> to [sale["account"]]<br>"
	parts += "<hr><i>[receipt_signoff]</i>"
	return parts.Join()

// ----- Vex: Undertow Exchange, red -----

/datum/xenoarch_buyer/vex
	extreme_vouchers = 1
	buys_curios = FALSE
	find_name = "dig pieces"
	find_desc = "Old alien finds. Vex has collectors in the deep ring who pay for the strange ones."
	find_icon_state = "spindle"
	receipt_title = "UNDERTOW EXCHANGE"
	receipt_signoff = "No returns. This never happened."
	receipt_font = PRINTER_FONT
	receipt_ink = "#111111"
	receipt_stamp = "stamp-void"
	inspect_sound = null
	lines = list(
		XENOARCH_LINE_NOTICE = list(
			"That's a dig piece. Bring it here. Slowly.",
			"Now that's a conversation piece. Over here.",
			"Collectors in the deep ring would kill for one of those. Some have.",
		),
		XENOARCH_LINE_INSPECT = list(
			"slides their sunglasses down and looks %THING% over without a word.",
			"walks once around %THING%, slowly.",
		),
		XENOARCH_LINE_INSPECT_CRATED = list(
			"lifts the lid of %THING% with one gloved finger and looks in.",
			"cracks %THING% open an inch and studies the gap.",
		),
		XENOARCH_LINE_CRACKED = list(
			"Cracked. Collectors hate cracks.",
			"Somebody dropped this. More than once.",
		),
		XENOARCH_LINE_TAPPED = list(
			"Tapped. Somebody's had their fun with this.",
			"Half of what it was. I can tell.",
		),
		XENOARCH_LINE_PERFECT = list(
			"Clean paperwork. My buyer likes clean paperwork.",
			"Label's right. That's rarer than the rock.",
		),
		XENOARCH_LINE_CLOSE = list(
			"Label's close enough for my buyer. Not for me.",
			"Mostly right. Mostly gets mostly paid.",
		),
		XENOARCH_LINE_WRONG = list(
			"Somebody guessed. I don't pay for guesses.",
			"Wrong label. My buyer's going to ask questions. I'll answer them, for a fee.",
		),
		XENOARCH_LINE_BLANK = list(
			"No label. You're selling me a rock with a story you don't know.",
			"Blank. Fine. I'll make up a story. Mine sell better.",
		),
		XENOARCH_LINE_LIVE = list(
			"Now this is worth something to people who don't deal in credits. Take the chit.",
			"My buyer's going to want this very badly. Here. A little extra.",
		),
		XENOARCH_LINE_WALKED = list(
			"Walking away. Smart, or stupid. We'll see.",
			"Suit yourself.",
		),
	)
	idle_lines = list(
		"The deep-ring collectors pay silly money for old dig pieces. The scarier the better.",
		"Somebody brought me a crystal that hummed in a key I didn't like. Sold it in an hour.",
	)

// Vex writes as little as possible down.
/datum/xenoarch_buyer/vex/receipt_text(list/sale)
	var/list/parts = list()
	parts += "<center><b>[receipt_title]</b></center><hr>"
	parts += "[sale["serial"]]. [sale["price"]] to [sale["account"]].[sale["vouchers"] ? " One chit." : ""]<br>"
	parts += "<hr><i>[receipt_signoff]</i>"
	return parts.Join()

// =========================================================================
// SHOPS AND TRADERS
// =========================================================================

/datum/outpost_shop
	/// /datum/xenoarch_buyer type for a shop that buys dig finds, or null
	var/xenoarch_buyer_type
	/// This shop's dig-find buyer, if it buys them
	var/datum/xenoarch_buyer/xenoarch_buyer

/datum/outpost_shop/general
	xenoarch_buyer_type = /datum/xenoarch_buyer/barnaby

/datum/outpost_shop/vendor/skunkworks
	xenoarch_buyer_type = /datum/xenoarch_buyer/boffin

/datum/outpost_shop/black_market
	xenoarch_buyer_type = /datum/xenoarch_buyer/vex

// The buyer's ledger rows go in before the base New() makes the buybacks, so they share the
// shop's demand and convoy restock like any other row.
/datum/outpost_shop/New(obj/structure/overmap/trader_outpost/outpost)
	if(xenoarch_buyer_type)
		xenoarch_buyer = new xenoarch_buyer_type(src)
		buyback_types = buyback_types + xenoarch_buyer.ledger_types()
		if(length(xenoarch_buyer.idle_lines))
			var/list/idle = trader_lines[TRADER_LINE_IDLE]
			trader_lines[TRADER_LINE_IDLE] = (islist(idle) ? idle : list()) + xenoarch_buyer.idle_lines
	. = ..()
	if(!xenoarch_buyer)
		return
	for(var/datum/shop_buyback/buyback as anything in buybacks)
		if(istype(buyback, /datum/shop_buyback/xenoarch_find))
			var/datum/shop_buyback/xenoarch_find/find_row = buyback
			find_row.attach(xenoarch_buyer)
		else if(istype(buyback, /datum/shop_buyback/xenoarch_curio))
			var/datum/shop_buyback/xenoarch_curio/curio_row = buyback
			curio_row.attach(xenoarch_buyer)

/datum/outpost_shop/Destroy()
	QDEL_NULL(xenoarch_buyer)
	return ..()

/mob/living/basic/outpost_trader/Life(seconds_per_tick, times_fired)
	. = ..()
	shop?.xenoarch_buyer?.look_around(src)

// =========================================================================
// LARGE FINDS
// =========================================================================

/**
 * # Large-find ledger row
 *
 * Buys the find the seller is pulling (loose, or in a shut crate), not anything in their pack.
 * item_path stays null on purpose: Pike's remote ledger and the contract pricing skip rows without
 * one, so a large find can only be sold by hauling it to an outpost.
 */
/datum/shop_buyback/xenoarch_find
	name = "dig pieces"
	desc = "Large finds out of the old dig sites."
	category = "Dig Finds"
	item_path = null
	demand_min = XENOARCH_FIND_DEMAND
	demand_max = XENOARCH_FIND_DEMAND
	/// The buyer whose ledger this is
	var/datum/xenoarch_buyer/buyer

/datum/shop_buyback/xenoarch_find/Destroy()
	buyer = null
	return ..()

/// Takes on `new_buyer`'s wording for the ledger.
/datum/shop_buyback/xenoarch_find/proc/attach(datum/xenoarch_buyer/new_buyer)
	buyer = new_buyer
	name = new_buyer.find_name
	desc = new_buyer.find_desc
	cached_icon = null

/datum/shop_buyback/xenoarch_find/get_ui_icon()
	if(!cached_icon && buyer)
		cached_icon = icon2base64(icon(buyer.find_icon, buyer.find_icon_state, SOUTH, frame = 1))
	return cached_icon

/datum/shop_buyback/xenoarch_find/get_payment_text()
	return "by the piece"

// Never an inventory item, whoever asks (plunder appraisal, Pike's ledger).
/datum/shop_buyback/xenoarch_find/matches(obj/item/offered)
	return FALSE

/datum/shop_buyback/xenoarch_find/find_refused_variant(mob/living/user)
	return null

/// The finds `user` is hauling that a buyer pays for (dug, and worth something), first to sell at the front.
/datum/shop_buyback/xenoarch_find/proc/sellable_finds(mob/living/user)
	. = list()
	for(var/obj/machinery/artifact/find as anything in xenoarch_hauled_finds(user))
		if(artifact_sale_value(find) > 0)
			. += find

// The trader takes one piece at a time, so a crate of three still shows one.
/datum/shop_buyback/xenoarch_find/count_carried_units(mob/living/user)
	if(!istype(user))
		return 0
	return length(sellable_finds(user)) ? 1 : 0

/// Whether `find` is close enough to `vendor` to be looked at.
/datum/shop_buyback/xenoarch_find/proc/at_counter(obj/machinery/artifact/find, mob/living/basic/outpost_trader/vendor)
	var/atom/movable/holder = xenoarch_find_holder(find)
	return !QDELETED(vendor) && holder && get_dist(holder, vendor) <= XENOARCH_COUNTER_REACH

/datum/shop_buyback/xenoarch_find/get_denial_reason(mob/living/user)
	if(demand <= 0)
		return "Not buying any more this shift."
	if(buyer?.is_busy())
		return "Already looking one over."
	var/list/hauled = xenoarch_hauled_finds(user)
	if(!length(hauled))
		return "Nothing at the counter."
	var/list/finds = sellable_finds(user)
	if(!length(finds))
		for(var/obj/machinery/artifact/find as anything in hauled)
			if(!find.is_dug())
				return "No field tag on it."
		return "Not buying that."
	if(!at_counter(finds[1], buyer?.trader()))
		return "Bring it closer."
	if(!get_shop_buyback_account(user))
		return "No bank account on your ID."
	return null

// The sale finishes once the trader has looked the find over, so this starts it and reports
// nothing sold yet: the window's own sale sound and line would come too early. The buyer makes
// their own noise when the money changes hands.
/datum/shop_buyback/xenoarch_find/try_sell(mob/living/user, mob/living/basic/outpost_trader/vendor, quiet = FALSE)
	if(!buyer || QDELETED(vendor))
		return FALSE
	INVOKE_ASYNC(src, PROC_REF(sell_hauled_find), user, vendor)
	return FALSE

/datum/shop_buyback/xenoarch_find/try_sell_bulk(mob/living/user, mob/living/basic/outpost_trader/vendor)
	try_sell(user, vendor)
	return 0

/// Whether the sale of `find` can still go ahead: same seller, same counter, still hauled, still wanted.
/datum/shop_buyback/xenoarch_find/proc/sale_still_on(mob/living/seller, mob/living/basic/outpost_trader/vendor, obj/machinery/artifact/find)
	if(QDELETED(src) || QDELETED(find) || QDELETED(vendor) || QDELETED(seller) || !buyer)
		return FALSE
	if(demand <= 0 || !(find in sellable_finds(seller)) || !at_counter(find, vendor))
		return FALSE
	if(!vendor.check_menu(seller) || vendor.outpost?.is_user_barred(seller))
		return FALSE
	if(vendor.outpost && !vendor.outpost.contains_site_turf(get_turf(vendor)))
		return FALSE
	return TRUE

/**
 * The seller waits at the counter while the trader looks over the first find they are hauling.
 * Walking off, letting go of it or the trader's demand running out calls it off. Sleeps.
 */
/datum/shop_buyback/xenoarch_find/proc/sell_hauled_find(mob/living/seller, mob/living/basic/outpost_trader/vendor)
	var/denial = get_denial_reason(seller)
	if(denial)
		to_chat(seller, span_warning(denial))
		vendor?.play_denial()
		return FALSE
	var/obj/machinery/artifact/find = sellable_finds(seller)[1]
	if(!sale_still_on(seller, vendor, find))
		vendor?.play_denial()
		return FALSE
	var/atom/movable/holder = xenoarch_find_holder(find)
	buyer.inspecting = WEAKREF(find)
	COOLDOWN_START(buyer, inspect_cooldown, XENOARCH_INSPECT_COOLDOWN)
	buyer.begin_inspection(vendor, find, holder)
	var/looked = do_after(seller, XENOARCH_INSPECT_TIME, holder, timed_action_flags = IGNORE_HELD_ITEM, extra_checks = CALLBACK(src, PROC_REF(sale_still_on), seller, vendor, find), hidden = TRUE)
	if(buyer)
		buyer.inspecting = null
	if(!looked || !sale_still_on(seller, vendor, find))
		if(!QDELETED(find) && buyer)
			buyer.speak(vendor, buyer.line(XENOARCH_LINE_WALKED))
		return FALSE
	if(settle(find, seller, get_shop_buyback_account(seller), vendor) > 0)
		return TRUE
	vendor.play_denial()
	return FALSE

/**
 * Pays for `find` and takes it: credits into `account`, any voucher and the receipt into the
 * seller's hands, the find gone. All checks and the payment happen without a sleep between them.
 * Returns the credits paid, or 0 if nothing was sold.
 */
/datum/shop_buyback/xenoarch_find/proc/settle(obj/machinery/artifact/find, mob/living/seller, datum/bank_account/account, mob/living/basic/outpost_trader/vendor)
	if(QDELETED(find) || !find.is_dug() || demand <= 0 || !account)
		return 0
	var/price = artifact_sale_value(find)
	if(price <= 0)
		return 0
	var/vouchers = buyer ? buyer.vouchers_for(find) : 0
	var/list/sale = buyer?.sale_record(find, seller, price, vouchers, account)
	var/reaction = buyer?.closing_line(find)
	var/atom/drop_spot = seller?.drop_location() || vendor?.drop_location() || get_turf(find)
	var/serial = find.serial
	var/trader_name = buyer?.shop?.trader_name || "The buyer"

	demand--
	SEND_SIGNAL(find, COMSIG_ARTIFACT_SOLD, price, vouchers, seller)
	metric_artifact_sold(find, seller, price, vouchers, buyer?.shop)
	log_game("XENOARCH: [key_name(seller)] sold [serial] ([find.main_effect?.log_name]) to [trader_name] for [price] cr[vouchers ? " and [vouchers] voucher\s" : ""] at [AREACOORD(drop_spot)].")
	if(isturf(find.loc))
		new /obj/effect/temp_visual/xenoarch_sold_find(find.loc, find)
	qdel(find)

	account.adjust_money(price, "Trader Outpost: [trader_name] bought [serial]")
	if(vouchers > 0)
		var/obj/item/stack/trade_voucher/chits = new(drop_spot, vouchers)
		seller?.put_in_hands(chits)
	if(sale)
		var/obj/item/paper/xenoarch_receipt/receipt = new(drop_spot)
		receipt.fill_in(buyer, sale)
		seller?.put_in_hands(receipt)
	if(!QDELETED(vendor))
		playsound(vendor, 'sound/effects/cashregister.ogg', 40, TRUE)
		if(sale)
			playsound(vendor, 'sound/items/handling/standard_stamp.ogg', 35, TRUE)
		buyer?.speak(vendor, reaction)
	if(seller)
		to_chat(seller, span_notice("[trader_name] pays [xenoarch_credits_text(price)] for [serial][vouchers ? " and slides over a trade voucher" : ""]."))
	return price

/// The sold find, fading off the counter as it is carried into the back.
/obj/effect/temp_visual/xenoarch_sold_find
	duration = 0.8 SECONDS
	randomdir = FALSE

/obj/effect/temp_visual/xenoarch_sold_find/Initialize(mapload, atom/movable/find)
	. = ..()
	if(find)
		icon = find.icon
		icon_state = find.icon_state
		pixel_x = find.pixel_x
		pixel_y = find.pixel_y
	animate(src, alpha = 0, pixel_z = 6, time = duration, easing = SINE_EASING | EASE_IN)

// =========================================================================
// CURIOS
// =========================================================================

/**
 * # Dug curio
 *
 * Marks a small find as having come out of a dig site, and what a buyer pays for it. Buyers take
 * only marked items, so strange objects from maintenance or the experimentor (never marked) can't
 * pass as finds. Copies made of a curio don't carry the mark.
 */
/datum/component/xenoarch_curio
	/// Credits a buyer pays for it
	var/value = 0

/datum/component/xenoarch_curio/Initialize(value)
	if(!isitem(parent))
		return COMPONENT_INCOMPATIBLE
	src.value = max(round(value), 0)

/// Marks `find` as a dug curio worth `value` credits to a buyer. Call when a small find comes out of the rock.
/proc/xenoarch_mark_curio(obj/item/find, value)
	if(!istype(find) || value <= 0)
		return FALSE
	find.AddComponent(/datum/component/xenoarch_curio, value)
	return TRUE

/// What a buyer pays for `thing` as a curio: 0 if it never came out of a dig site.
/proc/xenoarch_curio_value(obj/item/thing)
	var/datum/component/xenoarch_curio/mark = thing?.GetComponent(/datum/component/xenoarch_curio)
	return mark ? mark.value : 0

/**
 * # Curio ledger row
 *
 * An ordinary inventory buyback, except that every curio carries its own price. item_path stays
 * null so contract pricing and Pike's remote ledger leave it alone.
 */
/datum/shop_buyback/xenoarch_curio
	name = "curios"
	desc = "Small finds out of the old dig sites."
	category = "Dig Finds"
	item_path = null
	demand_min = XENOARCH_CURIO_DEMAND
	demand_max = XENOARCH_CURIO_DEMAND
	/// The buyer whose ledger this is
	var/datum/xenoarch_buyer/buyer
	/// Credits the last single sale paid (bulk sales add these up)
	var/last_sale_value = 0

/datum/shop_buyback/xenoarch_curio/Destroy()
	buyer = null
	return ..()

/// Takes on `new_buyer`'s wording for the ledger.
/datum/shop_buyback/xenoarch_curio/proc/attach(datum/xenoarch_buyer/new_buyer)
	buyer = new_buyer
	name = new_buyer.curio_name
	desc = new_buyer.curio_desc
	cached_icon = null

/datum/shop_buyback/xenoarch_curio/get_ui_icon()
	if(!cached_icon && buyer)
		cached_icon = icon2base64(icon(buyer.curio_icon, buyer.curio_icon_state, SOUTH, frame = 1))
	return cached_icon

/datum/shop_buyback/xenoarch_curio/get_payment_text()
	return "by the piece"

/datum/shop_buyback/xenoarch_curio/matches(obj/item/offered)
	if(!isitem(offered) || is_trader_good(offered))
		return FALSE
	if((offered.item_flags & ABSTRACT) || (offered.flags_1 & HOLOGRAM_1))
		return FALSE
	if(istype(offered, /obj/item/relic) && !buyer?.takes_strange_objects)
		return FALSE
	return xenoarch_curio_value(offered) > 0

/datum/shop_buyback/xenoarch_curio/find_refused_variant(mob/living/user)
	return null

/datum/shop_buyback/xenoarch_curio/get_denial_reason(mob/living/user)
	if(demand <= 0)
		return "Not buying any more this shift."
	if(count_carried_units(user) < 1)
		return "Carrying none of the goods: [get_wanted_text()]."
	if(!get_shop_buyback_account(user))
		return "No bank account on your ID."
	return null

/datum/shop_buyback/xenoarch_curio/try_sell(mob/living/user, mob/living/basic/outpost_trader/vendor, quiet = FALSE)
	last_sale_value = 0
	if(demand <= 0)
		return FALSE
	var/datum/bank_account/account = get_shop_buyback_account(user)
	if(!account)
		return FALSE
	var/list/found = find_offered_items(user)
	if(!length(found))
		return FALSE
	var/obj/item/curio = found[1]
	var/value = xenoarch_curio_value(curio)
	if(value <= 0)
		return FALSE
	var/curio_name = curio.name
	var/curio_type = curio.type
	qdel(curio)
	demand--
	account.adjust_money(value, "Trader Outpost: sold [curio_name]")
	last_sale_value = value
	if(!quiet)
		to_chat(user, span_notice("Sold: [curio_name] ([xenoarch_credits_text(value)])."))
	// The ordinary ledger metric, priced by the piece
	if(SSmetrics.accepting)
		var/list/details = list("name" = name, "sales" = 1, "curio" = curio_name)
		if(vendor?.shop)
			details["shop"] = "[vendor.shop.type]"
		record_metric(METRIC_TRADE, "shop_buyback", subject = curio_type, credits = value, quantity = 1, details = details, actor = user)
	return TRUE

/datum/shop_buyback/xenoarch_curio/try_sell_bulk(mob/living/user, mob/living/basic/outpost_trader/vendor)
	var/sold = 0
	var/total = 0
	var/safety = 50
	while(demand > 0 && safety-- > 0)
		if(!try_sell(user, vendor, quiet = TRUE))
			break
		sold++
		total += last_sale_value
	if(sold > 0)
		to_chat(user, span_notice("Sold [sold] [sold > 1 ? "curios" : "curio"] ([xenoarch_credits_text(total)])."))
	return sold

// =========================================================================
// THE RECEIPT
// =========================================================================

/// What a buyer hands over with the money: a dealer's paper, in their own hand.
/obj/item/paper/xenoarch_receipt
	name = "receipt"
	desc = "A dealer's receipt for something old and heavy."
	/// Paper stamp icon state to press on once the stamp sheet is ready
	var/pending_stamp

/obj/item/paper/xenoarch_receipt/proc/fill_in(datum/xenoarch_buyer/buyer, list/sale)
	name = "receipt ([sale["serial"]])"
	add_raw_text(buyer.receipt_text(sale), buyer.receipt_font, buyer.receipt_ink)
	update_appearance()
	if(buyer.receipt_stamp)
		pending_stamp = buyer.receipt_stamp
		// The stamp's class comes from the paper spritesheet, which may have to be made ready first
		INVOKE_ASYNC(src, PROC_REF(stamp_it))

/obj/item/paper/xenoarch_receipt/proc/stamp_it()
	var/datum/asset/spritesheet_batched/sheet = get_asset_datum(/datum/asset/spritesheet/simple/paper)
	if(QDELETED(src) || !sheet || !pending_stamp)
		return
	add_stamp(sheet.icon_class_name(pending_stamp), rand(180, 260), rand(40, 120), rand(-15, 15), pending_stamp)
	pending_stamp = null
	update_appearance()

#undef XENOARCH_FIND_DEMAND
#undef XENOARCH_CURIO_DEMAND
#undef XENOARCH_COUNTER_REACH
#undef XENOARCH_INSPECT_TIME
#undef XENOARCH_INSPECT_COOLDOWN
#undef XENOARCH_NOTICE_RANGE
#undef XENOARCH_NOTICE_COOLDOWN
#undef XENOARCH_NOTICE_MEMORY
#undef XENOARCH_LINE_NOTICE
#undef XENOARCH_LINE_INSPECT
#undef XENOARCH_LINE_INSPECT_CRATED
#undef XENOARCH_LINE_CRACKED
#undef XENOARCH_LINE_TAPPED
#undef XENOARCH_LINE_PERFECT
#undef XENOARCH_LINE_CLOSE
#undef XENOARCH_LINE_WRONG
#undef XENOARCH_LINE_BLANK
#undef XENOARCH_LINE_LIVE
#undef XENOARCH_LINE_WALKED
