/**
 * # Gene injector loot
 *
 * Single-use permanent DNA injectors found in zone loot caches (the loot theme tables).
 * Each one adds exactly one mutation. Unlike the stock tg injectors they
 * check the target before injecting and stay unused when the mutation
 * can't take, so a find is never wasted on a corpse, the wrong species, a
 * missing head or a conflicting gene. Every one carries TRAIT_NO_REPLICATE,
 * so duplicators can't copy them.
 *
 * Bought syndicate caches strip these (shop_catalog_black_market.dm), and
 * stock tg injectors are left alone for admins and mapped placements.
 */
/obj/item/dnainjector/loot
	desc = "A single-use DNA injector with a handwritten label."

/obj/item/dnainjector/loot/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/dnainjector/loot/update_desc(updates)
	. = ..()
	desc = "[initial(desc)][used ? " This one is used up." : null]"

/// The single mutation this injector adds.
/obj/item/dnainjector/loot/proc/get_loot_mutation()
	return length(add_mutations) ? add_mutations[1] : null

/// Whether the mutation would take on this target right now, mirroring /datum/mutation/proc/on_acquiring.
/obj/item/dnainjector/loot/proc/can_take(mob/living/carbon/target)
	if(!ishuman(target) || target.stat == DEAD || !target.can_mutate())
		return FALSE
	var/mutation_path = get_loot_mutation()
	var/datum/mutation/template = GET_INITIALIZED_MUTATION(mutation_path)
	if(!template)
		return FALSE
	var/mob/living/carbon/human/human_target = target
	var/datum/mutation/existing = human_target.dna.get_mutation(mutation_path)
	if(existing)
		// Already permanent: nothing to add. A temporary copy can be made permanent.
		return !length(existing.sources & list(MUTATION_SOURCE_ACTIVATED, MUTATION_SOURCE_MUTATOR))
	if(template.species_allowed && !template.species_allowed.Find(human_target.dna.species.id))
		return FALSE
	if(template.health_req && human_target.health < template.health_req)
		return FALSE
	if(template.limb_req && !human_target.get_bodypart(template.limb_req))
		return FALSE
	for(var/datum/mutation/held as anything in human_target.dna.mutations)
		if((held.type in template.conflicts) || (mutation_path in held.conflicts))
			return FALSE
	return TRUE

/obj/item/dnainjector/loot/inject(mob/living/carbon/target, mob/user)
	if(!can_take(target))
		return FALSE
	. = ..()
	if(!.)
		return
	// Belt and braces: never spend the injector unless the gene actually took.
	var/datum/mutation/gained = target.dna.get_mutation(get_loot_mutation())
	if(!gained || !length(gained.sources & list(MUTATION_SOURCE_ACTIVATED, MUTATION_SOURCE_MUTATOR)))
		return FALSE

/obj/item/dnainjector/loot/antenna
	name = "\improper DNA injector (Antenna)"
	desc = "A single-use DNA injector. Someone drew a little radio mast on the label."
	add_mutations = list(/datum/mutation/antenna)

/obj/item/dnainjector/loot/biotech
	name = "\improper DNA injector (Biotech Compatibility)"
	desc = "A single-use DNA injector stamped with a skillchip maker's logo."
	add_mutations = list(/datum/mutation/biotechcompat)

/obj/item/dnainjector/loot/telepathy
	name = "\improper DNA injector (Telepathy)"
	desc = "A single-use DNA injector. The label shows two heads facing each other."
	add_mutations = list(/datum/mutation/telepathy)

/obj/item/dnainjector/loot/cindikinesis
	name = "\improper DNA injector (Cindikinesis)"
	desc = "A single-use DNA injector with a smudge of ash on the cap."
	add_mutations = list(/datum/mutation/cindikinesis)

/obj/item/dnainjector/loot/glowy
	name = "\improper DNA injector (Glowy)"
	desc = "A single-use DNA injector that glows faintly in the dark."
	add_mutations = list(/datum/mutation/glow)

/obj/item/dnainjector/loot/gigantism
	name = "\improper DNA injector (Gigantism)"
	desc = "A single-use DNA injector labelled in very large letters."
	add_mutations = list(/datum/mutation/gigantism)

/obj/item/dnainjector/loot/geladikinesis
	name = "\improper DNA injector (Geladikinesis)"
	desc = "A single-use DNA injector, cold to the touch and frosted over."
	add_mutations = list(/datum/mutation/geladikinesis)

/obj/item/dnainjector/loot/strength
	name = "\improper DNA injector (Strength)"
	desc = "A single-use DNA injector from a gym's back room."
	add_mutations = list(/datum/mutation/strong)

/obj/item/dnainjector/loot/stimmed
	name = "\improper DNA injector (Stimmed)"
	desc = "A single-use DNA injector with a sports drink sticker on it."
	add_mutations = list(/datum/mutation/stimmed)

/obj/item/dnainjector/loot/rock_eater
	name = "\improper DNA injector (Rock Eater)"
	desc = "A single-use DNA injector with tooth marks on the casing."
	add_mutations = list(/datum/mutation/rock_eater)

/obj/item/dnainjector/loot/olfaction
	name = "\improper DNA injector (Olfaction)"
	desc = "A single-use DNA injector. The label shows a dog's nose."
	add_mutations = list(/datum/mutation/olfaction)

/obj/item/dnainjector/loot/farsight
	name = "\improper DNA injector (Farsight)"
	desc = "A single-use DNA injector with a pair of binoculars sketched on the label."
	add_mutations = list(/datum/mutation/farsight)

/obj/item/dnainjector/loot/cold_adaptation
	name = "\improper DNA injector (Cold Adaptation)"
	desc = "A single-use DNA injector with a snowflake on the label."
	add_mutations = list(/datum/mutation/adaptation/cold)

/obj/item/dnainjector/loot/heat_adaptation
	name = "\improper DNA injector (Heat Adaptation)"
	desc = "A single-use DNA injector, warm to the touch."
	add_mutations = list(/datum/mutation/adaptation/heat)

/obj/item/dnainjector/loot/insulated
	name = "\improper DNA injector (Insulated)"
	desc = "A single-use DNA injector wrapped in electrical tape."
	add_mutations = list(/datum/mutation/insulated)

/obj/item/dnainjector/loot/mind_reader
	name = "\improper DNA injector (Mind Reader)"
	desc = "A single-use DNA injector from an interrogator's kit."
	add_mutations = list(/datum/mutation/mindreader)

/obj/item/dnainjector/loot/anti_glow
	name = "\improper DNA injector (Anti-Glow)"
	desc = "A single-use DNA injector painted matte black."
	add_mutations = list(/datum/mutation/glow/anti)

/obj/item/dnainjector/loot/webbing
	name = "\improper DNA injector (Webbing)"
	desc = "A single-use DNA injector wrapped in sticky silk."
	add_mutations = list(/datum/mutation/webbing)

/obj/item/dnainjector/loot/autotomy
	name = "\improper DNA injector (Autotomy)"
	desc = "A single-use DNA injector. The label shows a lizard missing its tail."
	add_mutations = list(/datum/mutation/self_amputation)

/obj/item/dnainjector/loot/dwarfism
	name = "\improper DNA injector (Dwarfism)"
	desc = "A single-use DNA injector, slightly smaller than the usual kind."
	add_mutations = list(/datum/mutation/dwarfism)

/obj/item/dnainjector/loot/tongue_spike
	name = "\improper DNA injector (Tongue Spike)"
	desc = "A single-use DNA injector with a warning sticker about tongues."
	add_mutations = list(/datum/mutation/tongue_spike)

/obj/item/dnainjector/loot/hypermetabolic
	name = "\improper DNA injector (Hypermetabolic Blood)"
	desc = "A single-use DNA injector filled with something dark red."
	add_mutations = list(/datum/mutation/bloodier)

/obj/item/dnainjector/loot/plasmocile
	name = "\improper DNA injector (Plasmocile)"
	desc = "A single-use DNA injector with a plasma hazard sign crossed out."
	add_mutations = list(/datum/mutation/plasmocile)

/obj/item/dnainjector/loot/thermal_vision
	name = "\improper DNA injector (Thermal Vision)"
	desc = "A single-use DNA injector with a heat map printed on the label."
	add_mutations = list(/datum/mutation/thermal)

/obj/item/dnainjector/loot/cryokinesis
	name = "\improper DNA injector (Cryokinesis)"
	desc = "A single-use DNA injector with a blue hazard stripe and frost on the cap."
	add_mutations = list(/datum/mutation/cryokinesis)

/obj/item/dnainjector/loot/pyrokinesis
	name = "\improper DNA injector (Pyrokinesis)"
	desc = "A single-use DNA injector with scorch marks along the casing."
	add_mutations = list(/datum/mutation/pyrokinesis)

/obj/item/dnainjector/loot/elastic_arms
	name = "\improper DNA injector (Elastic Arms)"
	desc = "A single-use DNA injector with a rubber band around it."
	add_mutations = list(/datum/mutation/elastic_arms)

/obj/item/dnainjector/loot/chem_spike
	name = "\improper DNA injector (Chem Spike)"
	desc = "A single-use DNA injector marked with a biohazard sign and a tongue."
	add_mutations = list(/datum/mutation/tongue_spike/chem)

/obj/item/dnainjector/loot/pressure_adaptation
	name = "\improper DNA injector (Pressure Adaptation)"
	desc = "A single-use DNA injector from a deep salvage diving kit."
	add_mutations = list(/datum/mutation/adaptation/pressure)

/obj/item/dnainjector/loot/thermal_adaptation
	name = "\improper DNA injector (Thermal Adaptation)"
	desc = "A single-use DNA injector labelled for both arctic and furnace work."
	add_mutations = list(/datum/mutation/adaptation/thermal)

/obj/item/dnainjector/loot/shock_touch
	name = "\improper DNA injector (Shock Touch)"
	desc = "A single-use DNA injector with a lightning bolt on the label."
	add_mutations = list(/datum/mutation/shock)

/obj/item/dnainjector/loot/chameleon
	name = "\improper DNA injector (Chameleon)"
	desc = "A single-use DNA injector. It is hard to keep track of where you put it down."
	add_mutations = list(/datum/mutation/chameleon)

/obj/item/dnainjector/loot/fire_breath
	name = "\improper DNA injector (Fire Breath)"
	desc = "A single-use DNA injector that smells of lighter fluid."
	add_mutations = list(/datum/mutation/firebreath)

/obj/item/dnainjector/loot/fiery_sweat
	name = "\improper DNA injector (Fiery Sweat)"
	desc = "A single-use DNA injector with a sweat-stained label."
	add_mutations = list(/datum/mutation/fire)

/obj/item/dnainjector/loot/void_magnet
	name = "\improper DNA injector (Void Magnet)"
	desc = "A single-use DNA injector. The liquid inside is perfectly black."
	add_mutations = list(/datum/mutation/void)

/obj/item/dnainjector/loot/inexorable
	name = "\improper DNA injector (Inexorable)"
	desc = "A single-use DNA injector from a field medic's kit, marked for last resorts."
	add_mutations = list(/datum/mutation/inexorable)

/obj/item/dnainjector/loot/mending_touch
	name = "\improper DNA injector (Mending Touch)"
	desc = "A single-use DNA injector with an open palm printed on the label."
	add_mutations = list(/datum/mutation/lay_on_hands)

/obj/item/dnainjector/loot/adrenaline_rush
	name = "\improper DNA injector (Adrenaline Rush)"
	desc = "A single-use DNA injector with a racing heart drawn on the label."
	add_mutations = list(/datum/mutation/adrenaline_rush)

/obj/item/dnainjector/loot/quick_recovery
	name = "\improper DNA injector (Quick Recovery)"
	desc = "A single-use DNA injector from a stunt performer's kit."
	add_mutations = list(/datum/mutation/quick_recovery)

/obj/item/dnainjector/loot/martyrdom
	name = "\improper DNA injector (Martyrdom)"
	desc = "A single-use DNA injector with a skull and crossbones on the label."
	add_mutations = list(/datum/mutation/martyrdom)

/obj/item/dnainjector/loot/xray
	name = "\improper DNA injector (X-Ray Vision)"
	desc = "A single-use DNA injector. The label shows the bones of a hand."
	add_mutations = list(/datum/mutation/xray)

/obj/item/dnainjector/loot/telekinesis
	name = "\improper DNA injector (Telekinesis)"
	desc = "A single-use DNA injector. The label shows a wrench floating above a palm."
	add_mutations = list(/datum/mutation/telekinesis)

/obj/item/dnainjector/loot/laser_eyes
	name = "\improper DNA injector (Laser Eyes)"
	desc = "A single-use DNA injector with a pair of red eyes drawn on the label."
	add_mutations = list(/datum/mutation/laser_eyes)

/obj/item/dnainjector/loot/hulk
	name = "\improper DNA injector (Hulk)"
	desc = "A single-use DNA injector, dented as if someone squeezed it too hard."
	add_mutations = list(/datum/mutation/hulk)

/obj/item/dnainjector/loot/tough
	name = "\improper DNA injector (Tough)"
	desc = "A single-use DNA injector in a thick, scuffed casing."
	add_mutations = list(/datum/mutation/tough)

/obj/item/dnainjector/loot/dextrous
	name = "\improper DNA injector (Dextrous)"
	desc = "A single-use DNA injector from a surgeon's private stock."
	add_mutations = list(/datum/mutation/dextrous)

/obj/item/dnainjector/loot/quick
	name = "\improper DNA injector (Quick)"
	desc = "A single-use DNA injector with a running shoe on the label."
	add_mutations = list(/datum/mutation/quick)

/obj/item/dnainjector/loot/breathless
	name = "\improper DNA injector (Breathless)"
	desc = "A single-use DNA injector from a vacuum rescue kit, no mask included."
	add_mutations = list(/datum/mutation/breathless)

/obj/item/dnainjector/loot/fire_immunity
	name = "\improper DNA injector (Fire Immunity)"
	desc = "A single-use DNA injector in a fireproof sleeve."
	add_mutations = list(/datum/mutation/fire_immunity)

/obj/item/dnainjector/loot/rock_absorber
	name = "\improper DNA injector (Rock Absorber)"
	desc = "A single-use DNA injector with flecks of ore stuck to the casing."
	add_mutations = list(/datum/mutation/rock_absorber)
