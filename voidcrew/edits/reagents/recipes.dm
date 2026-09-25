/**
 * # Voidcrew virology: the virus evolution path
 *
 * Ported from tgstation #84356 / #89062 (hyperjll). Companion to the cure ladder, which lives
 * in place in code/datums/diseases/advance/advance.dm (it is a static var, so BYOND will not let
 * a later-included file re-declare it), and to voidcrew/edits/diseases/symptoms/ (the tier each
 * symptom sits at).
 *
 * ## What this changes
 *
 * Feeding a blood culture one of the virus foods makes
 * `/datum/chemical_reaction/mix_virus/on_reaction` call `D.Evolve(level_min, level_max)`, which
 * adds a random symptom whose `level` falls inside that band. Upstream's bands overlapped badly:
 * level 1 was reachable from two different foods, `mix_virus_5` held the 3 band *and* was
 * numbered above the 4 and 5 bands, and mutagen/plasma/uranium appeared as the "cheap" versions
 * of foods that also existed as their own tier. That is the slot machine viro players complained
 * about: the same reagent could land you anywhere in a two- or three-wide band.
 *
 * Every tier is now exactly one level wide and one food, ascending with rarity, so a recipe is a
 * deliberate step and not a roll:
 *
 *   level 1   virus food (base reaction)          level 7   raw plasma
 *   level 2   virus rations                       level 8   virus plasma
 *   level 3   mutagenic agar                      level 9   raw uranium
 *   level 4   raw mutagen                         level 10  unstable uranium gel
 *   level 5   sucrose agar                        level 11  decaying uranium gel
 *   level 6   weakened virus plasma               level 12  stable uranium gel
 *
 * The base reaction's `level_max` drops 2 -> 1, so plain virus food is the level-1 step only.
 *
 * These are the same reagents the restocked virology smartfridge hands out (see
 * voidcrew/modules/virology/bottles.dm), which is the point: the fridge stocks every rung of
 * this ladder so a doctor is never gated on a miner or a chemist making one specific food.
 *
 * ## Override syntax
 *
 * These files REPLACE existing datums and vars, so the declarations below use the override form:
 * `/datum/chemical_reaction/mix_virus/mix_virus_2` (not `.../proc/...`) and a bare
 * `level_max = 1` (not `var/level_max = 1`, which BYOND rejects as a duplicate definition).
 * `required_reagents`, `level_min` and `level_max` are inherited instance vars, so the reaction
 * body, the instant flag and the blood catalyst all stay upstream's.
 */
/datum/chemical_reaction/mix_virus
	level_max = 1

/datum/chemical_reaction/mix_virus/mix_virus_2
	required_reagents = list(/datum/reagent/medicine/synaptizine/synaptizinevirusfood = 1)
	level_min = 2
	level_max = 2

/datum/chemical_reaction/mix_virus/mix_virus_3
	required_reagents = list(/datum/reagent/toxin/mutagen/mutagenvirusfood = 1)
	level_min = 3
	level_max = 3

/datum/chemical_reaction/mix_virus/mix_virus_4
	required_reagents = list(/datum/reagent/toxin/mutagen = 1)
	level_min = 4
	level_max = 4

/datum/chemical_reaction/mix_virus/mix_virus_5
	required_reagents = list(/datum/reagent/toxin/mutagen/mutagenvirusfood/sugar = 1)
	level_min = 5
	level_max = 5

/datum/chemical_reaction/mix_virus/mix_virus_6
	required_reagents = list(/datum/reagent/toxin/plasma/plasmavirusfood/weak = 1)
	level_min = 6
	level_max = 6

/datum/chemical_reaction/mix_virus/mix_virus_7
	required_reagents = list(/datum/reagent/toxin/plasma = 1)
	level_min = 7
	level_max = 7

/datum/chemical_reaction/mix_virus/mix_virus_8
	required_reagents = list(/datum/reagent/toxin/plasma/plasmavirusfood = 1)
	level_min = 8
	level_max = 8

/datum/chemical_reaction/mix_virus/mix_virus_9
	required_reagents = list(/datum/reagent/uranium = 1)
	level_min = 9
	level_max = 9

/datum/chemical_reaction/mix_virus/mix_virus_10
	required_reagents = list(/datum/reagent/uranium/uraniumvirusfood/unstable = 1)
	level_min = 10
	level_max = 10

/datum/chemical_reaction/mix_virus/mix_virus_11
	required_reagents = list(/datum/reagent/uranium/uraniumvirusfood = 1)
	level_min = 11
	level_max = 11

/datum/chemical_reaction/mix_virus/mix_virus_12
	required_reagents = list(/datum/reagent/uranium/uraniumvirusfood/stable = 1)
	level_min = 12
	level_max = 12
