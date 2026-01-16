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
	/// Whether this faction accepts cargo as payment
	var/accepts_cargo = TRUE
	/// Whether this faction accepts counter-offers
	var/accepts_counter_offer = TRUE
	/// Multiplier on timeout duration (1.0 = normal, 2.0 = patient)
	var/patience_modifier = 1.0

	// Dialog line lists - will pick randomly from these
	var/list/greetings = list("Attention vessel. This is your only warning.")
	var/list/demand_lines = list("Pay us %CREDITS% credits or face destruction.")
	var/list/acceptance_lines = list("Wise choice. You may pass.")
	var/list/rejection_lines = list("Then you've chosen death.")
	var/list/timeout_lines = list("Your time is up!")
	var/list/impatience_lines = list("You're trying my patience... %SECONDS% seconds remaining.")
	var/list/counter_acceptance_lines = list("...Fine. %CREDITS% credits. Deal.")
	var/list/counter_rejection_lines = list("Don't insult me with such a pathetic offer.")
	var/list/counter_final_lines = list("Last chance. %CREDITS% credits. Take it or leave it.")
	var/list/payment_received_lines = list("Good. %VALUE% credits received.")
	var/list/cargo_rejection_lines = list("I don't want your junk. Credits only.")

/**
 * Get a greeting line when hailing begins.
 */
/datum/pirate_faction_dialog/proc/get_greeting()
	return pick(greetings)

/**
 * Get a demand line with the credit amount filled in.
 */
/datum/pirate_faction_dialog/proc/get_demand_line(credits)
	var/line = pick(demand_lines)
	return replacetextEx(line, "%CREDITS%", "[credits]")

/**
 * Get an acceptance line when payment is complete.
 */
/datum/pirate_faction_dialog/proc/get_acceptance_line()
	return pick(acceptance_lines)

/**
 * Get a rejection line when player refuses.
 */
/datum/pirate_faction_dialog/proc/get_rejection_line()
	return pick(rejection_lines)

/**
 * Get a timeout line when patience runs out.
 */
/datum/pirate_faction_dialog/proc/get_timeout_line()
	return pick(timeout_lines)

/**
 * Get an impatience line with seconds remaining.
 */
/datum/pirate_faction_dialog/proc/get_impatience_line(seconds)
	var/line = pick(impatience_lines)
	return replacetextEx(line, "%SECONDS%", "[seconds]")

/**
 * Get a line when counter-offer is accepted.
 */
/datum/pirate_faction_dialog/proc/get_counter_acceptance_line(credits)
	var/line = pick(counter_acceptance_lines)
	return replacetextEx(line, "%CREDITS%", "[credits]")

/**
 * Get a line when counter-offer is flatly rejected.
 */
/datum/pirate_faction_dialog/proc/get_counter_rejection_line()
	return pick(counter_rejection_lines)

/**
 * Get a final offer line after rejected counter-offer.
 */
/datum/pirate_faction_dialog/proc/get_counter_final_offer_line(credits)
	var/line = pick(counter_final_lines)
	return replacetextEx(line, "%CREDITS%", "[credits]")

/**
 * Get a line acknowledging partial payment.
 */
/datum/pirate_faction_dialog/proc/get_payment_received_line(value)
	var/line = pick(payment_received_lines)
	return replacetextEx(line, "%VALUE%", "[value]")

/**
 * Get a line rejecting cargo payment (for factions that don't accept it).
 */
/datum/pirate_faction_dialog/proc/get_cargo_rejection_line()
	return pick(cargo_rejection_lines)

// ========== FACTION SUBTYPES ==========

/**
 * IRS - Space Tax Collectors
 * Bureaucratic, formal, demanding. Credits only, no cargo.
 */
/datum/pirate_faction_dialog/irs
	faction_name = "Internal Revenue Service"
	demand_multiplier = 1.5  // IRS wants their cut
	accepts_cargo = FALSE     // Cash only
	accepts_counter_offer = FALSE  // No negotiating with the taxman
	patience_modifier = 0.8   // Bureaucrats are impatient

	greetings = list(
		"Attention vessel. This is the Internal Revenue Service. You have outstanding tax obligations.",
		"Your vessel has been flagged for audit. Prepare to remit payment immediately.",
		"IRS Enforcement. Our records indicate significant tax delinquency on your account.",
	)
	demand_lines = list(
		"You owe %CREDITS% credits in back taxes, fees, and penalties. Pay immediately.",
		"Your outstanding balance is %CREDITS% credits. Failure to pay will result in asset seizure.",
		"Total amount due: %CREDITS% credits. This is a final notice before enforcement action.",
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
	counter_rejection_lines = list(
		"The IRS does not negotiate. The amount owed is non-negotiable.",
		"Your counter-offer has been rejected. Pay the full amount.",
	)
	cargo_rejection_lines = list(
		"The IRS accepts monetary payment only. No bartering.",
		"We don't take goods. Credits. Now.",
	)

/**
 * Skeleton - The Flying Dutchman
 * Ominous, theatrical, cursed. Very patient undead.
 */
/datum/pirate_faction_dialog/skeleton
	faction_name = "The Flying Dutchman"
	demand_multiplier = 0.8   // Undead have simple needs
	accepts_cargo = TRUE
	accepts_counter_offer = TRUE
	patience_modifier = 2.0   // The dead are patient

	greetings = list(
		"Yarr... Another ship sails into our waters...",
		"The Dutchman demands tribute... or souls...",
		"We've been sailing these stars for centuries... and we hunger...",
	)
	demand_lines = list(
		"Surrender %CREDITS% credits worth of treasure... or join our eternal crew...",
		"The curse demands %CREDITS% in gold... Pay, or be damned alongside us...",
		"%CREDITS% credits... A small price to avoid our fate...",
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
	counter_acceptance_lines = list(
		"...Very well. %CREDITS% credits... The curse cares not for exact amounts...",
	)
	counter_final_lines = list(
		"%CREDITS% credits... Final offer... Choose wisely, mortal...",
	)
	payment_received_lines = list(
		"The Dutchman accepts your offering... %VALUE% credits...",
		"Treasure for the hoard... %VALUE% credits...",
	)

/**
 * Grey Tide - Rogue Assistants
 * Casual, chaotic, memetic. Will take anything.
 */
/datum/pirate_faction_dialog/grey
	faction_name = "Grey Tide"
	demand_multiplier = 0.7   // Assistants take what they can get
	accepts_cargo = TRUE
	accepts_counter_offer = TRUE
	patience_modifier = 0.7   // ADHD

	greetings = list(
		"Yo what's up, got any spare credits?",
		"GREYTIDE WORLDWIDE! Pay the toll!",
		"Hey! HEY! Stop your ship, we need to talk!",
		"Robust or get robbed, your choice!",
	)
	demand_lines = list(
		"Give us like %CREDITS% credits and we'll leave you alone, deal?",
		"We need %CREDITS% credits for... stuff. Important stuff. Hand it over!",
		"%CREDITS% credits! Come on, we know you've got it!",
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
	counter_acceptance_lines = list(
		"Eh, %CREDITS% credits works. Deal!",
		"Fine fine, %CREDITS%. Whatever!",
	)
	counter_final_lines = list(
		"Look, %CREDITS% credits, final offer. Take it or get toolboxed.",
	)
	payment_received_lines = list(
		"Nice, %VALUE% credits! Keep it coming!",
		"Cha-ching! %VALUE% credits!",
	)

/**
 * Medieval - Space Knights
 * Theatrical, archaic, honor-bound.
 */
/datum/pirate_faction_dialog/medieval
	faction_name = "The Order of the Void"
	demand_multiplier = 1.0
	accepts_cargo = TRUE
	accepts_counter_offer = TRUE
	patience_modifier = 1.2   // Knights are honorable and patient

	greetings = list(
		"Halt, vessel! You enter the domain of the Order!",
		"Hark! Surrender tribute or face our righteous fury!",
		"By the stars above, you shall pay homage to the Order!",
	)
	demand_lines = list(
		"Render unto us %CREDITS% credits in tribute, or face trial by combat!",
		"The Order demands %CREDITS% credits! Pay, or be vanquished!",
		"%CREDITS% credits, peasant! Such is the price of safe passage!",
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
	counter_acceptance_lines = list(
		"Hmm... %CREDITS% credits. A fair compromise. Agreed!",
	)
	counter_final_lines = list(
		"%CREDITS% credits. Our final offer. Decide now!",
	)
	payment_received_lines = list(
		"Tribute received! %VALUE% credits added to the war chest!",
	)

/**
 * Silverscale - Aristocratic Lizards
 * Haughty, dismissive, greedy.
 */
/datum/pirate_faction_dialog/silverscale
	faction_name = "Silverscale Dynasty"
	demand_multiplier = 1.3   // Aristocrats want more
	accepts_cargo = TRUE
	accepts_counter_offer = TRUE
	patience_modifier = 1.0

	greetings = list(
		"Attention, lesser vessel. You address the Silverscale Dynasty.",
		"Halt. You trespass in noble waters. Tribute is required.",
		"How... quaint. Your vessel. State your business or pay your dues.",
	)
	demand_lines = list(
		"The Dynasty requires %CREDITS% credits. A pittance for your continued existence.",
		"%CREDITS% credits. The Dynasty does not ask twice.",
		"You will pay %CREDITS% credits. This is not a request.",
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
	counter_acceptance_lines = list(
		"...Fine. %CREDITS% credits. The Dynasty accepts, reluctantly.",
	)
	counter_final_lines = list(
		"%CREDITS% credits. Final. Do not test our patience further.",
	)
	payment_received_lines = list(
		"%VALUE% credits. Continue.",
	)

/**
 * Interdyne - Ex-Pharmacists / Corporate
 * Clinical, detached, professional.
 */
/datum/pirate_faction_dialog/interdyne
	faction_name = "Interdyne Pharmaceutics"
	demand_multiplier = 1.2
	accepts_cargo = TRUE      // Especially medical supplies
	accepts_counter_offer = TRUE
	patience_modifier = 1.0

	greetings = list(
		"Interdyne Pharmaceutics. Your vessel has been flagged for resource acquisition.",
		"Attention vessel. You are within Interdyne operational parameters.",
		"This is Interdyne. We require... compensation for your continued operation.",
	)
	demand_lines = list(
		"Transfer %CREDITS% credits to facilitate mutual benefit.",
		"The acquisition cost is %CREDITS% credits. Payment is mandatory.",
		"%CREDITS% credits. A small investment in your continued biological function.",
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
	counter_acceptance_lines = list(
		"Counter-proposal evaluated. %CREDITS% credits accepted.",
	)
	counter_final_lines = list(
		"Final terms: %CREDITS% credits. Accept or face consequences.",
	)
	payment_received_lines = list(
		"Asset transfer confirmed. %VALUE% credits logged.",
	)

/**
 * Rogues - Standard Pirates
 * Rough, direct, opportunistic.
 */
/datum/pirate_faction_dialog/rogues
	faction_name = "Rogue Raiders"
	demand_multiplier = 1.0
	accepts_cargo = TRUE
	accepts_counter_offer = TRUE
	patience_modifier = 1.0

	greetings = list(
		"Well well, what do we have here?",
		"Stop right there! This is a robbery!",
		"Your credits or your life! Your choice!",
	)
	demand_lines = list(
		"Hand over %CREDITS% credits and nobody gets hurt.",
		"%CREDITS% credits. Now. Don't make this difficult.",
		"We want %CREDITS% credits. Pay up!",
	)
	acceptance_lines = list(
		"Smart choice. Get out of here before we change our minds.",
		"Pleasure doing business. Now scram!",
		"That'll do. You can go.",
	)
	rejection_lines = list(
		"Wrong answer! Open fire!",
		"Your funeral! Attack!",
		"Fine by me, we'll take it from your wreckage!",
	)
	timeout_lines = list(
		"Out of time! Attacking!",
		"That's it, we're done waiting!",
	)
	impatience_lines = list(
		"Tick tock! %SECONDS% seconds!",
		"We're losing patience here! %SECONDS% seconds!",
	)
	counter_acceptance_lines = list(
		"Hmm... %CREDITS% credits. Alright, deal.",
	)
	counter_final_lines = list(
		"%CREDITS% credits. Final offer. Take it or die.",
	)
	payment_received_lines = list(
		"Got it! %VALUE% credits! Keep it coming!",
	)

/**
 * Lustrous - Ethereal/Bluespace Entities
 * Mysterious, cryptic, otherworldly.
 */
/datum/pirate_faction_dialog/lustrous
	faction_name = "The Lustrous Collective"
	demand_multiplier = 1.0
	accepts_cargo = TRUE      // Especially bluespace items
	accepts_counter_offer = TRUE
	patience_modifier = 1.5   // Ethereal beings are patient

	greetings = list(
		"We... perceive you. Your vessel ripples through our domain.",
		"The Collective has noticed your presence. Tribute is... required.",
		"Mortal vessel. You intrude upon sacred frequencies.",
	)
	demand_lines = list(
		"Offer %CREDITS% credits to the Collective. We require... sustenance.",
		"%CREDITS% credits. The Collective demands this resonance.",
		"Your tribute: %CREDITS% credits. The crystals hunger.",
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
	counter_acceptance_lines = list(
		"The Collective... accepts. %CREDITS% credits will suffice.",
	)
	counter_final_lines = list(
		"%CREDITS% credits. The Collective offers this final resonance.",
	)
	payment_received_lines = list(
		"The Collective absorbs %VALUE% credits... The crystals pulse...",
	)
