/**
 * Pirate Faction Dialog
 *
 * Handles faction-specific personality, dialog lines, and negotiation modifiers.
 * Each faction has unique speech patterns and negotiation behavior.
 */
/datum/pirate_faction_dialog
	/// Display name of the faction
	var/faction_name = "Pirates"
	/// Multiplier on base demand (1.0 = normal, 1.5 = greedy, 0.7 = desperate)
	var/demand_multiplier = 1.0
	/// Multiplier on timeout duration (1.0 = normal, 2.0 = patient)
	var/patience_modifier = 1.0

	// Dialog line lists - will pick randomly from these
	var/list/greetings = list("Attention vessel. This is your only warning.")
	var/list/demand_lines = list("Pay us %CREDITS% credits, or bring me %QUANTITY% %ITEM%. Your choice.")
	/// Said when the target's accounts scanned empty, so we're asking for cargo instead.
	var/list/barter_demand_lines = list("Your accounts are empty, so we'll take goods instead. %QUANTITY% %ITEM% on the pad, and we leave.")
	/// Said when the crew stalls on a barter without handing anything over.
	var/list/barter_escalation_lines = list("You're wasting my time. The price is %QUANTITY% %ITEM% now. Move.")
	var/list/acceptance_lines = list("Wise choice. You may pass.")
	var/list/rejection_lines = list("Then you've chosen death.")
	var/list/timeout_lines = list("Your time is up!")
	var/list/impatience_lines = list("You're trying my patience... %SECONDS% seconds remaining.")
	var/list/flee_warning_lines = list("Nice try. You're not going anywhere. And for that little stunt, the price just went up.")
	var/list/movement_betrayal_lines = list("You tried that already! All weapons, FIRE!")
	var/list/escape_warning_lines = list("And don't even think about running. Try to move or target us, and we'll gun you down.")

	// Yellow-band shakedown variants. Weapons are barred outside red, so the threat
	// behind these negotiations is the data siphon - the lines above would promise a
	// broadside the pirate cannot fire. Picked instead whenever the negotiation
	// reports itself as a shakedown; see /datum/pirate_negotiation/is_siphon_shakedown.
	var/list/siphon_rejection_lines = list("Fine. We'll take it out of your accounts ourselves.")
	var/list/siphon_timeout_lines = list("Time's up. We're taking it directly.")
	var/list/siphon_movement_betrayal_lines = list("You tried that already! Hold them still and start the drain!")
	var/list/siphon_escape_warning_lines = list("And don't try running. Move on us and we'll just take the money ourselves.")

/**
 * Get a greeting line when hailing begins.
 */
/datum/pirate_faction_dialog/proc/get_greeting()
	return pick(greetings)

/**
 * Get a demand line with credits and item demand filled in.
 */
/datum/pirate_faction_dialog/proc/get_demand_line(credits, item_quantity, item_name)
	var/line = pick(demand_lines)
	line = replacetextEx(line, "%CREDITS%", "[credits]")
	line = replacetextEx(line, "%QUANTITY%", "[item_quantity]")
	line = replacetextEx(line, "%ITEM%", "[item_name]")
	return line

/**
 * Get a demand line for a cargo-only barter (target had no credits to take).
 */
/datum/pirate_faction_dialog/proc/get_barter_demand_line(item_quantity, item_name)
	var/line = pick(barter_demand_lines)
	line = replacetextEx(line, "%QUANTITY%", "[item_quantity]")
	line = replacetextEx(line, "%ITEM%", "[item_name]")
	return line

/**
 * Get a line for when a stalled barter demand gets raised.
 */
/datum/pirate_faction_dialog/proc/get_barter_escalation_line(item_quantity, item_name)
	var/line = pick(barter_escalation_lines)
	line = replacetextEx(line, "%QUANTITY%", "[item_quantity]")
	line = replacetextEx(line, "%ITEM%", "[item_name]")
	return line

/**
 * Get an acceptance line when payment is complete.
 */
/datum/pirate_faction_dialog/proc/get_acceptance_line()
	return pick(acceptance_lines)

/**
 * Get a rejection line when player refuses.
 *
 * siphon_shakedown: TRUE for a yellow-band shakedown, where refusing means the
 * pirate drains the accounts rather than opening fire.
 */
/datum/pirate_faction_dialog/proc/get_rejection_line(siphon_shakedown = FALSE)
	return pick(siphon_shakedown ? siphon_rejection_lines : rejection_lines)

/**
 * Get a timeout line when patience runs out.
 */
/datum/pirate_faction_dialog/proc/get_timeout_line(siphon_shakedown = FALSE)
	return pick(siphon_shakedown ? siphon_timeout_lines : timeout_lines)

/**
 * Get an impatience line with seconds remaining.
 */
/datum/pirate_faction_dialog/proc/get_impatience_line(seconds)
	var/line = pick(impatience_lines)
	return replacetextEx(line, "%SECONDS%", "[seconds]")

/**
 * Get a warning line when player tries to flee for the first time.
 */
/datum/pirate_faction_dialog/proc/get_flee_warning_line()
	return pick(flee_warning_lines)

/**
 * Get a line when player tries to move a second time (full betrayal).
 */
/datum/pirate_faction_dialog/proc/get_movement_betrayal_line(siphon_shakedown = FALSE)
	return pick(siphon_shakedown ? siphon_movement_betrayal_lines : movement_betrayal_lines)

/**
 * Get an escape warning line (said after demand to warn about movement).
 */
/datum/pirate_faction_dialog/proc/get_escape_warning_line(siphon_shakedown = FALSE)
	return pick(siphon_shakedown ? siphon_escape_warning_lines : escape_warning_lines)

// ========== FACTION SUBTYPES ==========

/**
 * IRS - Space Tax Collectors
 * Bureaucratic, formal, demanding.
 */
/datum/pirate_faction_dialog/irs
	faction_name = "Internal Revenue Service"
	demand_multiplier = 1.5  // IRS wants their cut
	patience_modifier = 0.8   // Bureaucrats are impatient

	greetings = list(
		"Attention vessel. This is the Internal Revenue Service. You have outstanding tax obligations.",
		"Your vessel has been flagged for audit. Prepare to remit payment immediately.",
		"IRS Enforcement. Our records indicate significant tax delinquency on your account.",
	)
	demand_lines = list(
		"You owe %CREDITS% credits in back taxes. Alternatively, surrender %QUANTITY% %ITEM% as asset forfeiture.",
		"Your outstanding balance is %CREDITS% credits. Or provide %QUANTITY% %ITEM% for immediate compliance.",
		"Total amount due: %CREDITS% credits. We will also accept %QUANTITY% %ITEM% as payment in kind.",
	)
	barter_demand_lines = list(
		"Your accounts hold nothing collectable. We are proceeding to asset forfeiture. Surrender %QUANTITY% %ITEM%.",
		"Audit complete: no liquid funds. Settle the balance in kind. %QUANTITY% %ITEM%, on the pad.",
		"You cannot pay in credits, so we will collect in goods. %QUANTITY% %ITEM% closes this file.",
	)
	barter_escalation_lines = list(
		"Late filing penalty applied. The assessment is now %QUANTITY% %ITEM%.",
		"Your delay has been added to the balance. %QUANTITY% %ITEM%. Do not make it three.",
	)
	acceptance_lines = list(
		"Payment received. Your account has been noted as compliant. For now.",
		"Transaction complete. The IRS thanks you for your... cooperation.",
		"Taxes paid. You may proceed. Don't let us catch you again.",
	)
	rejection_lines = list(
		"Tax evasion is a serious offense. Prepare for aggressive asset recovery.",
		"You've chosen the hard way. Commencing enforcement protocols.",
		"Non-compliance detected. Initiating punitive measures.",
	)
	timeout_lines = list(
		"Your payment window has closed. Enforcement action authorized.",
		"Time's up. The IRS does not grant extensions.",
	)
	impatience_lines = list(
		"You have %SECONDS% seconds to remit payment before penalties increase.",
		"The IRS does not wait. %SECONDS% seconds remaining.",
	)
	flee_warning_lines = list(
		"Attempting to evade an audit? Interdiction engaged. Your penalties have increased.",
		"Fleeing from the IRS is a federal offense. You're not going anywhere. And your debt just grew.",
	)
	movement_betrayal_lines = list(
		"Repeat evasion attempt logged. Lethal enforcement authorized!",
		"You were warned. Commencing aggressive asset seizure!",
	)
	escape_warning_lines = list(
		"Any attempt to flee or engage our vessels will be considered an act of tax terrorism.",
		"Do not attempt evasion. Our enforcement drones will pursue and eliminate.",
	)
	siphon_rejection_lines = list(
		"Refusal noted. Switching to direct account levy.",
		"You've chosen the hard way. We'll garnish it at the source.",
		"Non-compliance recorded. Your accounts are now subject to seizure.",
	)
	siphon_timeout_lines = list(
		"Your payment window has closed. Automatic collection begins now.",
		"Time's up. We'll debit the balance ourselves.",
	)
	siphon_movement_betrayal_lines = list(
		"Repeat evasion attempt logged. Levy the accounts.",
		"You were warned. Direct seizure authorized.",
	)
	siphon_escape_warning_lines = list(
		"Do not attempt evasion. We can pull the funds whether you cooperate or not.",
		"Running only changes how we collect, not whether we do.",
	)

/**
 * Skeleton - The Flying Dutchman
 * Ominous, theatrical, cursed. Very patient undead.
 */
/datum/pirate_faction_dialog/skeleton
	faction_name = "The Flying Dutchman"
	demand_multiplier = 0.8   // Undead have simple needs
	patience_modifier = 2.0   // The dead are patient

	greetings = list(
		"Yarr... Another ship sails into our waters...",
		"The Dutchman demands tribute... or souls...",
		"We've been sailing these stars for centuries... and we hunger...",
	)
	demand_lines = list(
		"Surrender %CREDITS% credits... or bring us %QUANTITY% %ITEM%... or join our eternal crew...",
		"The curse demands %CREDITS% in gold... or %QUANTITY% %ITEM%... Pay, or be damned...",
		"%CREDITS% credits... or %QUANTITY% %ITEM%... A small price to avoid our fate...",
	)
	barter_demand_lines = list(
		"No gold in your coffers... then we take cargo... %QUANTITY% %ITEM%, and we sail on...",
		"Empty hold, empty pockets... Bring us %QUANTITY% %ITEM% and keep your souls...",
		"Coin means nothing to the dead anyway... %QUANTITY% %ITEM%... that will do...",
	)
	barter_escalation_lines = list(
		"You stall... The dead do not stall... %QUANTITY% %ITEM% now...",
		"Our patience is long, but it is not endless... %QUANTITY% %ITEM%...",
	)
	acceptance_lines = list(
		"Your tribute is... acceptable. Sail on, living one. For now...",
		"The Dutchman is satisfied... This time...",
		"Go... before we change our minds...",
	)
	rejection_lines = list(
		"Then welcome to eternity... You'll make a fine addition to the crew...",
		"So be it... Your soul will serve the Dutchman...",
		"A foolish choice... The curse claims another...",
	)
	timeout_lines = list(
		"Your time among the living... is over...",
		"The Dutchman waits for no one... Not even the living...",
	)
	impatience_lines = list(
		"%SECONDS% seconds... The crew grows restless...",
		"The cursed souls hunger... %SECONDS% seconds...",
	)
	flee_warning_lines = list(
		"You cannot outrun the curse... Now your debt to us grows...",
		"The Dutchman's grasp tightens... Your tribute has increased...",
	)
	movement_betrayal_lines = list(
		"Twice you tried to flee... Now you join the crew... FOREVER!",
		"Your soul is forfeit! The curse claims you!",
	)
	escape_warning_lines = list(
		"Flee... and the curse will find you... There is no escape from the Dutchman...",
		"Do not attempt to run... The dead are patient... and relentless...",
	)
	siphon_rejection_lines = list(
		"Then we take it from your coffers ourselves... You'll not miss it...",
		"So be it... The gold comes to us either way...",
		"A foolish choice... We'll empty your accounts and sail on...",
	)
	siphon_timeout_lines = list(
		"Your silence costs you... We take the gold ourselves now...",
		"The Dutchman waits no longer... Your coffers are ours...",
	)
	siphon_movement_betrayal_lines = list(
		"Twice you flee... Hold them fast, and take every coin...",
		"You'll not slip away... Drain them dry...",
	)
	siphon_escape_warning_lines = list(
		"Run if you like... The gold sails to us all the same...",
		"You cannot outrun a debt... We'll pull it from your coffers ourselves...",
	)

/**
 * Grey Tide - Rogue Assistants
 * Casual, chaotic, memetic. Will take anything.
 */
/datum/pirate_faction_dialog/grey
	faction_name = "Grey Tide"
	demand_multiplier = 0.7   // Assistants take what they can get
	patience_modifier = 0.7   // ADHD

	greetings = list(
		"Yo what's up, got any spare credits?",
		"GREYTIDE WORLDWIDE! Pay the toll!",
		"Hey! HEY! Stop your ship, we need to talk!",
		"Robust or get robbed, your choice!",
	)
	demand_lines = list(
		"Give us %CREDITS% credits or %QUANTITY% %ITEM%, your choice!",
		"We need %CREDITS% credits! Or like %QUANTITY% %ITEM%, whatever works!",
		"%CREDITS% credits or %QUANTITY% %ITEM%! Come on, hand it over!",
	)
	barter_demand_lines = list(
		"lmao ur broke. fine, just give us %QUANTITY% %ITEM% and we'll go",
		"no creds? whatever, we'll take stuff. %QUANTITY% %ITEM% on the pad",
		"ok so you got nothing. cool cool. %QUANTITY% %ITEM% then, hand it over",
	)
	barter_escalation_lines = list(
		"BRO. it's %QUANTITY% %ITEM% now. you did that",
		"tick tock! price went up, %QUANTITY% %ITEM%, lets GO",
	)
	acceptance_lines = list(
		"NICE! Thanks buddy, you're cool. Grey tide approved!",
		"Aight bet, we're out. Stay robust!",
		"That's what I'm talking about! Later!",
	)
	rejection_lines = list(
		"Bro really? Fine, TOOLBOX TIME!",
		"Your loss! GREY TIDE NEVER DIES!",
		"Aight you asked for it, GET ROBUST!",
	)
	timeout_lines = list(
		"TOO SLOW! GREYTIDE ATTACKS!",
		"That's it, I'm bored. Attacking!",
	)
	impatience_lines = list(
		"Come on come on come on! %SECONDS% seconds!",
		"Hurry up! %SECONDS% seconds! I got places to be!",
	)
	flee_warning_lines = list(
		"BRO! Did you just try to run?! Nah nah nah, you're paying MORE now!",
		"LOL nice try! You're not going anywhere! And that's gonna cost you extra!",
	)
	movement_betrayal_lines = list(
		"AGAIN?! Okay that's IT! TOOLBOX TIME FOR REAL!",
		"You just don't learn! GET ROBUST!",
	)
	escape_warning_lines = list(
		"Don't even THINK about running bro, we got toolboxes and we're not afraid to use them!",
		"Try to dip and we'll robust you SO hard!",
	)
	siphon_rejection_lines = list(
		"Bro really? Fine, we're just hacking your account then.",
		"Your loss! We'll take it ourselves, nerd!",
		"Aight, siphon time. Should've just paid.",
	)
	siphon_timeout_lines = list(
		"TOO SLOW! We're draining your account!",
		"That's it, I'm bored. Taking it myself!",
	)
	siphon_movement_betrayal_lines = list(
		"AGAIN?! Okay that's IT! Hold em still, I'm siphoning!",
		"You just don't learn! Draining you dry!",
	)
	siphon_escape_warning_lines = list(
		"Don't even THINK about running bro, we'll just yoink the credits.",
		"Try to dip and we take it out of your account anyway!",
	)

/**
 * Medieval - Space Knights
 * Theatrical, archaic, honor-bound.
 */
/datum/pirate_faction_dialog/medieval
	faction_name = "The Order of the Void"
	demand_multiplier = 1.0
	patience_modifier = 1.2   // Knights are honorable and patient

	greetings = list(
		"Halt, vessel! You enter the domain of the Order!",
		"Hark! Surrender tribute or face our righteous fury!",
		"By the stars above, you shall pay homage to the Order!",
	)
	demand_lines = list(
		"Render unto us %CREDITS% credits in tribute, or bring %QUANTITY% %ITEM%! Or face trial by combat!",
		"The Order demands %CREDITS% credits! Or %QUANTITY% %ITEM%! Pay, or be vanquished!",
		"%CREDITS% credits, peasant! Or %QUANTITY% %ITEM%! Such is the price of safe passage!",
	)
	barter_demand_lines = list(
		"Thy coffers are bare! Very well - tribute in goods, then. %QUANTITY% %ITEM%, and thou may pass!",
		"A pauper's vessel! The Order accepts %QUANTITY% %ITEM% in place of coin!",
		"No purse to empty, so we shall take from thy hold. %QUANTITY% %ITEM%!",
	)
	barter_escalation_lines = list(
		"Thou dost dawdle! The tribute is now %QUANTITY% %ITEM%!",
		"Test not our honour with delay! %QUANTITY% %ITEM%, and be quick!",
	)
	acceptance_lines = list(
		"Your tribute is accepted. Go with honor, traveler.",
		"The Order recognizes your wisdom. Safe travels.",
		"Well met! Your generosity shall be remembered.",
	)
	rejection_lines = list(
		"So be it! DEUS VULT! For glory and honor!",
		"You have chosen... poorly. TO ARMS!",
		"Then let the stars bear witness to your doom!",
	)
	timeout_lines = list(
		"Your hesitation dishonors us both! En garde!",
		"The time for parley has ended! CHARGE!",
	)
	impatience_lines = list(
		"Make haste! %SECONDS% seconds remain before we attack!",
		"The Order's patience wanes... %SECONDS% seconds!",
	)
	flee_warning_lines = list(
		"COWARD! You dare flee?! Your dishonor demands a greater tribute!",
		"Stay your vessel, knave! For this transgression, the toll increases!",
	)
	movement_betrayal_lines = list(
		"TWICE you show cowardice?! There is no redemption! CHARGE!",
		"Your dishonor knows no bounds! TO ARMS, BROTHERS!",
	)
	escape_warning_lines = list(
		"Flee not, coward! Any attempt to escape shall be met with righteous fury!",
		"A knight never runs, and neither shall you. Stay your engines, or face our wrath!",
	)
	siphon_rejection_lines = list(
		"So be it! We shall levy the tribute ourselves!",
		"You have chosen... poorly. Take what is owed!",
		"Then the Order collects by its own hand!",
	)
	siphon_timeout_lines = list(
		"The time for parley has ended! Seize the tribute!",
		"Your hesitation dishonors us both! We take what we are owed!",
	)
	siphon_movement_betrayal_lines = list(
		"TWICE you show cowardice?! Hold them fast and take the tribute!",
		"Your dishonor knows no bounds! Empty their coffers!",
	)
	siphon_escape_warning_lines = list(
		"Flee not, knave! The tribute shall be taken from thy coffers regardless!",
		"A knight never runs. Run, and we simply help ourselves to thy purse!",
	)

/**
 * Silverscale - Aristocratic Lizards
 * Haughty, dismissive, greedy.
 */
/datum/pirate_faction_dialog/silverscale
	faction_name = "Silverscale Dynasty"
	demand_multiplier = 1.3   // Aristocrats want more
	patience_modifier = 1.0

	greetings = list(
		"Attention, lesser vessel. You address the Silverscale Dynasty.",
		"Halt. You trespass in noble waters. Tribute is required.",
		"How... quaint. Your vessel. State your business or pay your dues.",
	)
	demand_lines = list(
		"The Dynasty requires %CREDITS% credits. Or %QUANTITY% %ITEM%. A pittance for your continued existence.",
		"%CREDITS% credits. Or %QUANTITY% %ITEM%. The Dynasty does not ask twice.",
		"You will pay %CREDITS% credits. Or provide %QUANTITY% %ITEM%. This is not a request.",
	)
	barter_demand_lines = list(
		"Destitute. How disappointing. Then the Dynasty will take goods. %QUANTITY% %ITEM%.",
		"You have no money worth the counting. Provide %QUANTITY% %ITEM% instead.",
		"Your accounts are beneath notice. Your hold, perhaps less so. %QUANTITY% %ITEM%.",
	)
	barter_escalation_lines = list(
		"You keep the Dynasty waiting. The price is %QUANTITY% %ITEM% now.",
		"Delay is its own insult. %QUANTITY% %ITEM%. Do not test us further.",
	)
	acceptance_lines = list(
		"Adequate. You may proceed. Do not test our patience again.",
		"The Dynasty accepts. You are dismissed.",
		"Your tribute is... acceptable. Barely.",
	)
	rejection_lines = list(
		"How dare you! You will regret this insult to the Dynasty!",
		"Insolence! Prepare to face Silverscale justice!",
		"You refuse the Dynasty? Unforgivable!",
	)
	timeout_lines = list(
		"We do not wait for commoners. Attack!",
		"Your indecision bores us. Engaging!",
	)
	impatience_lines = list(
		"The Dynasty does not appreciate delays. %SECONDS% seconds.",
		"You waste our time. %SECONDS% seconds remaining.",
	)
	flee_warning_lines = list(
		"You DARE attempt to flee from the Dynasty?! The tribute has increased. Significantly.",
		"Foolish commoner. You are going nowhere. And you will pay dearly for this insult.",
	)
	movement_betrayal_lines = list(
		"Twice you insult the Dynasty?! UNFORGIVABLE! Destroy them!",
		"Your insolence knows no bounds! The Dynasty will END you!",
	)
	escape_warning_lines = list(
		"Do not presume to flee from your betters. The Dynasty's reach is absolute.",
		"Attempt to run, and we will make an example of you. The Dynasty does not tolerate cowardice.",
	)
	siphon_rejection_lines = list(
		"How dare you. Very well - the Dynasty will help itself.",
		"Insolence. We will take it from your accounts directly.",
		"You refuse? Then you have no say in how much we take.",
	)
	siphon_timeout_lines = list(
		"We do not wait for commoners. Take it from their accounts.",
		"Your indecision bores us. Begin the withdrawal.",
	)
	siphon_movement_betrayal_lines = list(
		"Twice you insult the Dynasty?! Hold them and empty their accounts!",
		"Your insolence knows no bounds! Take everything we are owed!",
	)
	siphon_escape_warning_lines = list(
		"Do not presume to flee. Your accounts are already within our reach.",
		"Run if you must. The Dynasty will simply collect without your cooperation.",
	)

/**
 * Interdyne - Ex-Pharmacists / Corporate
 * Clinical, detached, professional.
 */
/datum/pirate_faction_dialog/interdyne
	faction_name = "Interdyne Pharmaceutics"
	demand_multiplier = 1.2
	patience_modifier = 1.0

	greetings = list(
		"Interdyne Pharmaceutics. Your vessel has been flagged for resource acquisition.",
		"Attention vessel. You are within Interdyne operational parameters.",
		"This is Interdyne. We require... compensation for your continued operation.",
	)
	demand_lines = list(
		"Transfer %CREDITS% credits. Or provide %QUANTITY% %ITEM%. Either will facilitate mutual benefit.",
		"The acquisition cost is %CREDITS% credits. Alternatively, %QUANTITY% %ITEM% is acceptable.",
		"%CREDITS% credits. Or %QUANTITY% %ITEM%. A small investment in your continued biological function.",
	)
	barter_demand_lines = list(
		"No liquid funds located. Switching to physical asset recovery. Provide %QUANTITY% %ITEM%.",
		"Your accounts are not viable. Material compensation will suffice: %QUANTITY% %ITEM%.",
		"Credit transfer is not an option here. Transfer %QUANTITY% %ITEM% to our custody instead.",
	)
	barter_escalation_lines = list(
		"Delay has been priced in. The requirement is now %QUANTITY% %ITEM%.",
		"Your hesitation has adjusted the terms. %QUANTITY% %ITEM%. Comply.",
	)
	acceptance_lines = list(
		"Transaction complete. Interdyne thanks you for your cooperation.",
		"Payment received. You may proceed. This interaction is concluded.",
		"Satisfactory. Your vessel is cleared for departure.",
	)
	rejection_lines = list(
		"Non-compliance detected. Initiating aggressive acquisition protocols.",
		"Rejected. Alternative resource extraction methods will be employed.",
		"Your refusal has been noted. Commencing hostile takeover.",
	)
	timeout_lines = list(
		"Negotiation window expired. Initiating combat protocols.",
		"Time allocated for compliance exceeded. Engaging.",
	)
	impatience_lines = list(
		"Processing delay detected. %SECONDS% seconds until protocol escalation.",
		"%SECONDS% seconds remaining in compliance window.",
	)
	flee_warning_lines = list(
		"Evasion attempt detected. Interdiction engaged. Acquisition cost has been adjusted upward.",
		"Flight protocol intercepted. You're not going anywhere. Processing fee increased.",
	)
	movement_betrayal_lines = list(
		"Second evasion attempt logged. Initiating lethal acquisition protocols.",
		"Continued non-compliance detected. Termination authorized.",
	)
	escape_warning_lines = list(
		"Evasion protocols are inadvisable. Our targeting systems have already achieved lock.",
		"Any attempt to flee will trigger immediate termination protocols. Compliance is optimal.",
	)
	siphon_rejection_lines = list(
		"Non-compliance detected. Switching to direct account extraction.",
		"Rejected. Funds will be recovered without your authorization.",
		"Your refusal has been noted. Beginning unassisted transfer.",
	)
	siphon_timeout_lines = list(
		"Negotiation window expired. Initiating direct fund recovery.",
		"Compliance window exceeded. Extracting payment automatically.",
	)
	siphon_movement_betrayal_lines = list(
		"Second evasion attempt logged. Immobilize and begin extraction.",
		"Continued non-compliance detected. Direct account access authorized.",
	)
	siphon_escape_warning_lines = list(
		"Evasion is inadvisable. Our systems can reach your accounts from here.",
		"Flight does not prevent collection. It only removes your say in the amount.",
	)

/**
 * Lustrous - Ethereal/Bluespace Entities
 * Mysterious, cryptic, otherworldly.
 */
/datum/pirate_faction_dialog/lustrous
	faction_name = "The Lustrous Collective"
	demand_multiplier = 1.0
	patience_modifier = 1.5   // Ethereal beings are patient

	greetings = list(
		"We... perceive you. Your vessel ripples through our domain.",
		"The Collective has noticed your presence. Tribute is... required.",
		"Mortal vessel. You intrude upon sacred frequencies.",
	)
	demand_lines = list(
		"Offer %CREDITS% credits to the Collective... Or %QUANTITY% %ITEM%... We require... sustenance.",
		"%CREDITS% credits... Or %QUANTITY% %ITEM%... The Collective demands this resonance.",
		"Your tribute: %CREDITS% credits... Or %QUANTITY% %ITEM%... The crystals hunger.",
	)
	barter_demand_lines = list(
		"You carry no wealth we can take... Then give us matter instead... %QUANTITY% %ITEM%...",
		"Your accounts are hollow... but your hold is not... %QUANTITY% %ITEM%...",
		"Credits mean nothing to the crystals... %QUANTITY% %ITEM% will feed them...",
	)
	barter_escalation_lines = list(
		"You delay, and the hunger grows... %QUANTITY% %ITEM% now...",
		"The Collective has waited long enough... %QUANTITY% %ITEM%...",
	)
	acceptance_lines = list(
		"The Collective is... satisfied. You may continue your trajectory.",
		"Your resonance is accepted. Depart in peace.",
		"Sufficient. The crystals sing with contentment.",
	)
	rejection_lines = list(
		"Then the Collective shall take what it requires...",
		"Your refusal echoes through the void. We will claim you.",
		"So be it. Your energy will be harvested directly.",
	)
	timeout_lines = list(
		"Your silence speaks volumes. The Collective takes action.",
		"The resonance fades. We must... intervene.",
	)
	impatience_lines = list(
		"The frequencies grow unstable... %SECONDS% seconds...",
		"%SECONDS% seconds before the Collective acts...",
	)
	flee_warning_lines = list(
		"You cannot escape our perception... The resonance tightens... Your tribute grows...",
		"We felt your intent to flee... Now you are bound... And you will pay more...",
	)
	movement_betrayal_lines = list(
		"Twice you try to phase away... The Collective will consume you...",
		"Your resistance is... irritating. We will harvest you directly.",
	)
	escape_warning_lines = list(
		"Do not attempt to phase away... The Collective perceives all trajectories...",
		"Flight is... meaningless... We exist in all frequencies... You cannot escape...",
	)
	siphon_rejection_lines = list(
		"Then the Collective takes what it requires... directly...",
		"Your refusal changes nothing... The wealth flows to us either way...",
		"So be it. We will draw it from your accounts ourselves...",
	)
	siphon_timeout_lines = list(
		"Your silence speaks volumes... We take it now...",
		"The resonance fades... The Collective collects...",
	)
	siphon_movement_betrayal_lines = list(
		"Twice you try to phase away... Hold them, and draw it out...",
		"Your resistance is... irritating. We take the wealth directly.",
	)
	siphon_escape_warning_lines = list(
		"Do not attempt to phase away... Your accounts resonate within our reach...",
		"Flight is meaningless... The wealth comes to us regardless...",
	)
