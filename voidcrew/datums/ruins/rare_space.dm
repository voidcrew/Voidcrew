/**
 * # Rare space ruins
 *
 * Rumor-chart exclusives. unpickable = TRUE keeps them out of natural seeding
 * and replacement respawns, the only road to one is buying its chart from an
 * outpost trader (see voidcrew/modules/trade/rumor_charts.dm).
 */
/datum/map_template/ruin/space/rare
	prefix = "_maps/voidcrew/RandomRuins/SpaceRuins/"
	unpickable = TRUE
	allow_duplicates = FALSE

/datum/map_template/ruin/space/rare/armory
	id = "rare_armory"
	suffix = "rare_armory.dmm"
	name = "Bastion-6 Deadstock Depot"
	description = "A mothballed Nanotrasen munitions barge with its automated defenses still live. The decommissioning crew died locked out of their own vault. Their cutting job is half finished and the guns are still on the racks."

/datum/map_template/ruin/space/rare/biolab
	id = "rare_biolab"
	suffix = "rare_biolab.dmm"
	name = "Eventide Exotics Annex"
	description = "An off-the-books Nanotrasen xenobiology lab that stopped filing reports mid-shift. The specimens got loose and ate the staff. Nobody made it to the extract vault."

/datum/map_template/ruin/space/rare/pirate_cove
	id = "rare_pirate_cove"
	suffix = "rare_pirate_cove.dmm"
	name = "The Scuppers Freeport"
	description = "A smugglers' freeport dug into a hollow asteroid. The crews mutinied over the split, the quartermaster sealed the hoard, and everyone who knew the combination shot each other. The survivors are still aboard, and still armed."

/datum/map_template/ruin/space/rare/reliquary
	id = "rare_reliquary"
	suffix = "rare_reliquary.dmm"
	name = "Pilgrim's Vow Reliquary"
	description = "A prayer barge that went dark on pilgrimage a generation ago. Something answered the congregation's prayers, and the service never ended. The crypt below still holds the grave goods of everyone aboard."

/datum/map_template/ruin/space/rare/foundry
	id = "rare_foundry"
	suffix = "rare_foundry.dmm"
	name = "Helios-Betna Forgeworks"
	description = "An automated alloy foundry whose owners went bankrupt decades ago. The overseer system never got the memo. The line still runs, the custodian bots still patrol, and the finished-goods vault has never shipped a crate."

/datum/map_template/ruin/space/rare/hospice
	id = "rare_hospice"
	suffix = "rare_hospice.dmm"
	name = "CSV Meridian"
	description = "A plague evacuation ship scuttled under permanent quarantine with the patients still in their beds. Nobody ever emptied the wards, and nobody ever touched the pharmacy."

/datum/map_template/ruin/space/rare/blacksite
	id = "rare_blacksite"
	suffix = "rare_blacksite.dmm"
	name = "Kestrel Anchorage"
	description = "A Syndicate forward depot that stopped answering its handlers two years ago. The garrison is still on station and still following its last orders. The equipment lockers were never stripped."

/datum/map_template/ruin/space/rare/liner
	id = "rare_liner"
	suffix = "rare_liner.dmm"
	name = "MV Ambassador"
	description = "A passenger liner that lost main power halfway through a long crossing and was written off with everyone's luggage still aboard. The purser's hold was sealed before the crew abandoned ship."

/datum/map_template/ruin/space/rare/survey
	id = "rare_survey"
	suffix = "rare_survey.dmm"
	name = "Longwatch Station"
	description = "A deep-range survey post that kept transmitting for eleven years after its last resupply. The sample vault is intact, and so is whatever the crew brought back inside with them."

/datum/map_template/ruin/space/rare/bitrunner_den
	id = "rare_bitrunner_den"
	suffix = "rare_bitrunner_den.dmm"
	name = "Nullstack Arcade"
	description = "An unlicensed parlour that rented netpod time by the hour and sold whatever its forge printed. The server ran past its cooling limit for years and the safeties gave out mid-session, so it started compiling the domain's hostiles into the room instead of the loot. The runners died in their pods. The rig is still powered and still bolted down."
