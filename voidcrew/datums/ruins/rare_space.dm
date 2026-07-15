/**
 * # Rare space ruins
 *
 * Rumor-chart exclusives. unpickable = TRUE keeps them out of natural seeding
 * and replacement respawns — the only road to one is buying its chart from an
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
	description = "A mothballed Nanotrasen munitions barge whose asset-denial grid never stood down. The decommissioning crew died locked out of their own vault — their breach is still half-cut, and the deadstock is still racked."

/datum/map_template/ruin/space/rare/biolab
	id = "rare_biolab"
	suffix = "rare_biolab.dmm"
	name = "Eventide Exotics Annex"
	description = "An off-ledger Nanotrasen xenobiology annex that stopped filing reports mid-shift. The specimens are loose, the staff are part of the inventory now, and the extract vault never got the evacuation order."

/datum/map_template/ruin/space/rare/pirate_cove
	id = "rare_pirate_cove"
	suffix = "rare_pirate_cove.dmm"
	name = "The Scuppers Freeport"
	description = "A smugglers' freeport dug into a hollow asteroid. The crews mutinied over the split, the quartermaster sealed the hoard, and everyone who knew the combination shot each other. The survivors are still aboard, and still armed."

/datum/map_template/ruin/space/rare/reliquary
	id = "rare_reliquary"
	suffix = "rare_reliquary.dmm"
	name = "Pilgrim's Vow Reliquary"
	description = "A votive barge that went dark on pilgrimage a generation ago. Something answered the congregation's prayers, and it has never let the service end. The crypt still holds the grave-goods of every soul aboard."

/datum/map_template/ruin/space/rare/foundry
	id = "rare_foundry"
	suffix = "rare_foundry.dmm"
	name = "Helios-Betna Forgeworks"
	description = "An automated alloy foundry whose owners defaulted decades ago. The overseer system never got the memo: the line still runs, the custodian units still patrol, and the finished-goods vault has never shipped a single crate."

/datum/map_template/ruin/space/rare/hospice
	id = "rare_hospice"
	suffix = "rare_hospice.dmm"
	name = "CSV Meridian"
	description = "A plague evacuation ship scuttled under permanent quarantine seal with the patients still in their beds. The wards never emptied and the pharmacy was never rationed out — the seal held better than the cure did."
