/**
 * # Job packs
 *
 * A department in a crate: every circuitboard the discipline needs, plus the
 * hand equipment that discipline's locker would have held on a station. These
 * are meant to be a purchasable substitute for a research bay, the same way
 * Sarge's Ship Systems shelf substitutes for one on thrusters and turrets.
 *
 * Why they're worth buying: machine boards only print on a circuit imprinter,
 * and while any ship can build one from roundstart (the autolathe stocks the
 * R&D Kit: see voidcrew/modules/research/designs/autolathe_designs.dm), the
 * boards themselves still sit behind the techweb. Robotics and basic botany are
 * starting nodes and effectively free; xenobiology is tier 3 behind the whole
 * cytology ladder, and gene engineering is tier 4 behind xenobiology on top of
 * that. A crate skips that grind for money instead.
 *
 * Placement follows each stall's existing "no overlap" rule, and the zone ladder
 * tracks the techweb depth being bypassed:
 * - Botany      -> Fern, Waystation Halcyon (green). Credits only; she runs the
 *                  seed counter and this is her department.
 * - Robotics    -> Boffin, Quartermain Depot (yellow). Cheap, because robotics
 *                  is a starting node. The crate buys a fab, not research.
 * - Xenobiology -> Boffin, Quartermain Depot (yellow). Dearer; tier-3 chain.
 * - Genetics    -> Sawbones, the Undertow (red). Dearest; tier-4 chain, and a
 *                  black-market clinic is the right counter to sell it over.
 *
 * Balance notes:
 * - Crates, not boxes. /obj/item/storage/box caps at seven slots and every pack
 *   here is bigger than that. Crates also dispense at the buyer's feet, which
 *   the shop already handles, see dispense() in shop.dm.
 * - No stock parts in any pack. Tier-1 parts print on a stock ship autolathe for
 *   free, so bundling them would pad the price without adding capability. Boffin
 *   sells the tier-2 ladder separately and that stays the upgrade path.
 * - The robotics pack has no flashes on purpose. Those are Sarge's Security Gear
 *   shelf one counter over, and hand-building a cyborg isn't the headline use of
 *   an exosuit fabricator.
 * - Stock is deliberately low. A pack is a shortcut, not a supply line.
 */

// =========================================================================
// THE CRATES
// =========================================================================

/obj/structure/closet/crate/hydroponics/botany_pack
	name = "botany starter crate"
	desc = "A grower's outfit packed for transit: tray and processing boards on top, tools and workwear underneath."

/obj/structure/closet/crate/hydroponics/botany_pack/PopulateContents()
	. = ..()
	// Two trays is the smallest number that makes crossbreeding possible.
	new /obj/item/circuitboard/machine/hydroponics(src)
	new /obj/item/circuitboard/machine/hydroponics(src)
	new /obj/item/circuitboard/machine/seed_extractor(src)
	new /obj/item/circuitboard/machine/biogenerator(src)
	new /obj/item/plant_analyzer(src)
	new /obj/item/cultivator(src)
	new /obj/item/hatchet(src)
	new /obj/item/secateurs(src)
	new /obj/item/shovel/spade(src)
	new /obj/item/reagent_containers/cup/watering_can(src)
	new /obj/item/storage/bag/plants(src)
	new /obj/item/clothing/gloves/botanic_leather(src)
	new /obj/item/clothing/under/rank/civilian/hydroponics(src)
	new /obj/item/clothing/suit/apron(src)

/obj/structure/closet/crate/science/robotics_pack
	name = "robotics starter crate"
	desc = "An exosuit fabricator board, a bare endoskeleton and a positronic brain, packed with a mechanic's kit and a diagnostic HUD."

/obj/structure/closet/crate/science/robotics_pack/PopulateContents()
	. = ..()
	new /obj/item/circuitboard/machine/mechfab(src)
	new /obj/item/robot_suit(src)
	new /obj/item/mmi/posibrain(src)
	new /obj/item/storage/toolbox/mechanical(src)
	new /obj/item/clothing/glasses/hud/diagnostic(src)
	new /obj/item/assembly/prox_sensor(src)
	new /obj/item/assembly/prox_sensor(src)
	new /obj/item/stack/cable_coil(src)
	new /obj/item/clothing/suit/toggle/labcoat/roboticist(src)
	new /obj/item/clothing/under/rank/rnd/roboticist(src)

/obj/structure/closet/crate/science/xenobiology_pack
	name = "xenobiology starter crate"
	desc = "Boards, tools, monkey cubes, a grey slime extract and 15 units of liquid plasma. Build and power the machines with frames and stock parts; switch the processor to slime mode with a screwdriver. Build a secure pen in view of a ship camera before injecting the extract with at least 1 unit of plasma to hatch a slime. Rehydrate monkey cubes with water for feeding."

/obj/structure/closet/crate/science/xenobiology_pack/PopulateContents()
	. = ..()
	new /obj/item/circuitboard/computer/xenobiology(src)
	// The processor ships in food mode; a screwdriver switches it to slimes.
	new /obj/item/circuitboard/machine/processor(src)
	new /obj/item/circuitboard/machine/monkey_recycler(src)
	new /obj/item/slime_scanner(src)
	new /obj/item/storage/box/monkeycubes(src)
	new /obj/item/slime_extract/grey(src)
	new /obj/item/reagent_containers/syringe/plasma(src)
	new /obj/item/extinguisher/mini(src)
	new /obj/item/clothing/suit/toggle/labcoat/science(src)
	new /obj/item/clothing/under/rank/rnd/scientist(src)

/obj/structure/closet/crate/medical/genetics_pack
	name = "genetics starter crate"
	desc = "Scanner, console and infuser boards for a genetics lab, packed with a sequence scanner, blank data disks and a set of whites."

/obj/structure/closet/crate/medical/genetics_pack/PopulateContents()
	. = ..()
	new /obj/item/circuitboard/machine/dnascanner(src)
	new /obj/item/circuitboard/computer/scan_consolenew(src)
	new /obj/item/circuitboard/machine/dna_infuser(src)
	new /obj/item/sequence_scanner(src)
	new /obj/item/disk/data(src)
	new /obj/item/disk/data(src)
	new /obj/item/clothing/suit/toggle/labcoat/genetics(src)
	new /obj/item/clothing/under/rank/rnd/geneticist(src)

// =========================================================================
// THE SKUs
// =========================================================================
// Each subtypes its own shop's SKU family so it inherits that stall's
// conventions. The category string must match an entry in the shop's
// categories list or the SKU never renders.

/// Fern, The Potting Shed: Waystation Halcyon (green zone)
/datum/shop_sku/potting/job_pack_botany
	category = "Job Packs"
	name = "botany starter pack"
	desc = "Two tray boards, a seed extractor and a biogenerator, plus tools and gloves. Requires machine frames, stock parts, power, water and seeds to start growing."
	item_path = /obj/structure/closet/crate/hydroponics/botany_pack
	price_credits = 1000
	stock_min = 1
	stock_max = 2

/// Boffin, The Skunkworks: Quartermain Depot (yellow zone)
/datum/shop_sku/skunk/job_pack_robotics
	category = "Job Packs"
	name = "robotics starter pack"
	desc = "An exosuit fabricator board, endoskeleton, positronic brain and bench tools. Build the fabricator with a machine frame and stock parts, supply power and materials, and link research for advanced designs."
	item_path = /obj/structure/closet/crate/science/robotics_pack
	price_credits = 1200
	stock_min = 1
	stock_max = 2

/// Boffin, The Skunkworks: Quartermain Depot (yellow zone)
/datum/shop_sku/skunk/job_pack_xenobiology
	category = "Job Packs"
	name = "xenobiology starter pack"
	desc = "Console, processor and recycler boards, tools, monkey cubes, a grey extract and 15u liquid plasma. Requires frames, parts and power. Build a secure pen in view of a ship camera before injecting at least 1u plasma into the extract to hatch a slime. Add water to monkey cubes for food; screwdriver the processor board into slime mode."
	item_path = /obj/structure/closet/crate/science/xenobiology_pack
	price_credits = 1800
	stock_min = 1
	stock_max = 1

/// Sawbones, the Patch-Up Clinic: the Undertow (red zone)
/datum/shop_sku/clinic/job_pack_genetics
	category = "Job Packs"
	name = "genetics starter pack"
	desc = "Scanner, console and infuser boards, a sequence scanner and blank disks. Requires frames, stock parts, power and a subject; rehydrated monkey cubes provide a starting subject."
	item_path = /obj/structure/closet/crate/medical/genetics_pack
	price_credits = 2400
	stock_min = 1
	stock_max = 1
