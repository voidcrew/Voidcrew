// Voidcrew extensions to code/modules/mining/machine_redemption.dm.

// satchel emptying and deposit feedback.
// Rounds 14/15 (round 4, two crews): the ORM only ate bare ore stacks and ore boxes off
// its input tile, so a mining satchel pressed against the machine or dropped on the tile
// did nothing ("it won't empty"), and when ore did go in it became silo materials and
// machine-held mining points with no message at all ("did it just fucking steal my ore?").
// Every deposit path now runs through smelt_ore(), which speaks one summary of what was
// stored and where it went.

/// Inserts one ore stack into the silo/local storage and logs it toward the next spoken
/// deposit summary. Returns the insert result (<= 0 means rejected, same contract as
/// remote_materials insert_item()).
/obj/machinery/mineral/ore_redemption/proc/smelt_ore(obj/item/stack/ore/gathered_ore, alist/user_data)
	var/points_before = points
	var/ore_name = gathered_ore.name
	. = materials.insert_item(gathered_ore, ore_multiplier, user_data = user_data)
	if(. <= 0)
		return
	LAZYINITLIST(pending_deposit_report)
	pending_deposit_report[ore_name] += round(. / SHEET_MATERIAL_AMOUNT, 0.1)
	pending_deposit_points += points - points_before
	if(!deposit_report_timer)
		// Short delay so one satchel or ore box dump reads as one message, not thirty
		deposit_report_timer = addtimer(CALLBACK(src, PROC_REF(report_deposits)), 2 SECONDS, TIMER_STOPPABLE)

/// Says a single plain summary for everything deposited over the last couple of seconds.
/obj/machinery/mineral/ore_redemption/proc/report_deposits()
	deposit_report_timer = null
	if(!length(pending_deposit_report))
		return
	var/list/parts = list()
	for(var/ore_name in pending_deposit_report)
		var/sheets = pending_deposit_report[ore_name]
		parts += "[sheets] sheet[sheets == 1 ? "" : "s"] from [ore_name]"
	var/destination = materials.silo ? "the ore silo" : "this machine"
	var/summary = "Deposit processed: [parts.Join(", ")]. The sheets are held in [destination] - take them out here, or spend them from any fabricator on the same network."
	if(pending_deposit_points > 0)
		summary += " [pending_deposit_points] mining point\s earned - claim them at this machine with your ID."
	say(summary)
	pending_deposit_report = null
	pending_deposit_points = 0

/// Clicking the machine with a mining satchel empties every smeltable ore stack in it.
/obj/machinery/mineral/ore_redemption/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/storage/bag/ore))
		return ..()
	if(panel_open)
		balloon_alert(user, "close the panel first!")
		return ITEM_INTERACT_BLOCKING
	if(!powered())
		balloon_alert(user, "no power!")
		return ITEM_INTERACT_BLOCKING
	if(!materials.mat_container)
		balloon_alert(user, "no material storage connected!")
		return ITEM_INTERACT_BLOCKING
	var/list/obj/item/stack/ore/ore_list = list()
	for(var/obj/item/stack/ore/ore_item in tool.contents)
		ore_list += ore_item
	if(!length(ore_list))
		balloon_alert(user, "no ore in [tool.name]!")
		return ITEM_INTERACT_BLOCKING
	var/deposited_any = FALSE
	var/rejected_any = FALSE
	for(var/obj/item/stack/ore/gathered_ore as anything in ore_list)
		if(isnull(gathered_ore.refined_type))
			rejected_any = TRUE
			continue
		if(smelt_ore(gathered_ore, user_data = ID_DATA(user)) <= 0)
			rejected_any = TRUE
			continue
		deposited_any = TRUE
		SEND_SIGNAL(src, COMSIG_ORM_COLLECTED_ORE)
	if(!deposited_any)
		balloon_alert(user, "nothing in [tool.name] can be smelted!")
		return ITEM_INTERACT_BLOCKING
	if(rejected_any)
		to_chat(user, span_notice("You empty [tool] into [src]. Anything it could not smelt is still in the bag."))
	else
		to_chat(user, span_notice("You empty [tool] into [src]."))
	if(!console_notify_timer)
		console_notify_timer = addtimer(CALLBACK(src, PROC_REF(send_console_message)), 5 SECONDS)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/mineral/ore_redemption
	/// Sheets deposited since the last spoken summary, keyed by ore name
	var/list/pending_deposit_report
	/// Mining points earned since the last spoken summary
	var/pending_deposit_points = 0
	/// Timer that collects one whole dump into a single spoken summary
	var/deposit_report_timer
