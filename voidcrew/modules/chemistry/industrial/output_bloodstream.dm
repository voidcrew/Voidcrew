/**
 * BCI chemistry components.
 *
 * Ported from monkestation's wiremod_chem module (components/targetted/).
 *
 * Base type for chemistry components that live in a brain-computer interface and act on
 * the person wearing it.
 */
/obj/item/circuit_component/chem/bci
	required_shells = list(/obj/item/organ/cyberimp/bci) //VOIDCREW ADAPTATION: tg flattened /obj/item/organ/internal/* to /obj/item/organ/*
	circuit_flags = CIRCUIT_FLAG_INPUT_SIGNAL

	var/obj/item/organ/cyberimp/bci/bci

/obj/item/circuit_component/chem/bci/register_shell(atom/movable/shell)
	if(istype(shell, /obj/item/organ/cyberimp/bci))
		bci = shell

/obj/item/circuit_component/chem/bci/unregister_shell(atom/movable/shell)
	bci = null

/**
 * Chemical pump integration.
 *
 * Injects a chemical list straight into the wearer's bloodstream.
 *
 * NOTE: this ships unobtainable by design - it has no techweb design and is on the
 * chemical circuit board's blacklist, so it cannot be printed or installed. Upstream
 * monkestation reached the same conclusion: a self-refilling in-brain chem pump with no
 * dose ceiling is not something to hand out until somebody balances it. The code is here
 * so the BCI plumbing exists for anyone who wants to finish the job.
 */
/obj/item/circuit_component/chem/bci/bloodstream
	display_name = "Chemical Pump Integration"
	desc = "A component that integrates directly into your veins to inject you with reagents."
	energy_usage_per_input = 0.0001 * STANDARD_CELL_CHARGE

	var/datum/port/input/input_reagents
	var/datum/port/input/input_heat
	/// When we last told the owner what was happening, so we don't spam them every pulse.
	COOLDOWN_DECLARE(message_cooldown)

/obj/item/circuit_component/chem/bci/bloodstream/populate_ports()
	input_heat = add_input_port("Desired Heat", PORT_TYPE_NUMBER, default = 275)
	input_reagents = add_input_port("Chemical Input", PORT_TYPE_CHEMICAL_LIST, order = 1.1)

/obj/item/circuit_component/chem/bci/bloodstream/input_received(datum/port/input/port, list/return_values)
	if(!bci)
		return
	var/mob/living/owner = bci.owner
	if(!owner?.reagents)
		return

	var/list/payload = input_reagents.value
	if(!length(payload))
		return

	owner.reagents.add_reagent_list(payload, temperature = sanitize_heat(input_heat))

	//VOIDCREW FIX: monkestation wrote `if(last_message >= world.time + 5 SECONDS) return`,
	//which can never be true, so the message fired on every single pulse.
	if(!COOLDOWN_FINISHED(src, message_cooldown))
		return
	COOLDOWN_START(src, message_cooldown, 5 SECONDS)
	to_chat(owner, span_notice("You feel chemicals pumping into your veins."))

/obj/item/circuit_component/chem/bci/bloodstream/after_work_call()
	clear_all_temp_ports()

/obj/item/circuit_component/chem/bci/bloodstream/clear_all_temp_ports()
	input_reagents.value = null
