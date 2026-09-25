/**
 * # Voidcrew virology: the speed modifiers the new symptoms hand out
 *
 * The ported PR scattered these across code/modules/actionspeed/modifiers/virus.dm and
 * code/modules/movespeed/modifiers/reagent.dm. They are only ever granted by virology symptoms,
 * so they live with the rest of the module instead of in two upstream directories.
 *
 * `/datum/actionspeed_modifier/diseasestim` is granted by Muscular Dexterity at stage 4+, and
 * `diseasestimbuffed` replaces it at the same stage when the Resistance 7 threshold is met (the
 * symptom swaps one for the other rather than stacking them).
 *
 * ## `/datum/movespeed_modifier/viro_dexterity` is a rescue, not a straight port
 *
 * The PR shipped two orphan reagent datums - `/datum/reagent/antihardcrit` (Conscience
 * Stabilizers) and `/datum/reagent/diseasensstim` (Neurological Stimulants) - which nothing in
 * the game ever created. The stimulant's entire body was `add_movespeed_modifier()` on metabolism,
 * a 5% movement buff. Rather than keep a reagent no symptom produces, or delete the effect, that
 * buff now comes from where it always should have: Muscular Dexterity's Stage Speed 2 threshold,
 * alongside the carry speed it already grants there. The modifier is renamed out of the
 * `reagent/` namespace because no reagent grants it any more.
 *
 * The other orphan, `antihardcrit`, is replaced by a trait grant on Regenerative Coma - see
 * voidcrew/edits/diseases/symptoms/coma.dm.
 */

/// +5% action speed while a virus is speeding the host's hands up.
/datum/actionspeed_modifier/diseasestim
	multiplicative_slowdown = -0.05

/// +10% action speed with Muscular Dexterity's Resistance 7 threshold met.
/datum/actionspeed_modifier/diseasestimbuffed
	multiplicative_slowdown = -0.1

/// +5% movement speed with Muscular Dexterity's Stage Speed 2 threshold met.
/datum/movespeed_modifier/viro_dexterity
	multiplicative_slowdown = -0.05
