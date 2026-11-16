// Biotech Compatibility also raises neural capacity, so the gene injector
// (voidcrew/modules/loot/gene_injectors.dm) is worth a prime slot. The bonus is
// read through a trait by get_chrome_capacity() in the cyberware module.
/datum/mutation/biotechcompat/on_acquiring(mob/living/carbon/human/owner)
	. = ..()
	if(!.)
		return
	ADD_TRAIT(owner, TRAIT_BIOTECH_NEURAL, GENETIC_MUTATION)
	cyberware_reevaluate_brownout(owner)

/datum/mutation/biotechcompat/on_losing(mob/living/carbon/human/owner)
	REMOVE_TRAIT(owner, TRAIT_BIOTECH_NEURAL, GENETIC_MUTATION)
	cyberware_reevaluate_brownout(owner)
	return ..()
