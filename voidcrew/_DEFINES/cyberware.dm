// Cyberware: chrome load, slots, tiers, Cradle timings (voidcrew/modules/cyberware/)

/// Baseline chrome capacity of a carbon body. Installed ware sums its
/// chrome_load against this; the Overclock Governor raises it via the
/// component's capacity_bonus hook. Going over doesn't block removal,
/// it browns every piece of chrome out until the load drops back under.
#define CYBERWARE_BASE_CAPACITY 20

/// Mob-overlay height worn chrome draws at: between the character-setup
/// underwear/undershirt layer (BODY_LAYER, 32) and the eyes (EYES_LAYER, 31),
/// so a spine rig reads over a bra or undershirt while every EQUIPPED
/// clothing layer (UNIFORM_LAYER 28 and up) still covers it. Fractional on
/// purpose, it must never collide with a real layer index.
#define CYBERWARE_WORN_LAYER 31.5

// ---- Organ slots -------------------------------------------------------
// Minted here, never in DNA.dm. Slot uniqueness is global per mob, so
// same-slot ware forms an upgrade ladder or a mutually exclusive choice.
// The optics ladder deliberately has NO slot of its own: it rides tg's
// ORGAN_SLOT_EYES via /obj/item/organ/eyes/robotic/cyberware.

/// THE operating-system choice, chest. Cascade Lattice vs Redline Core.
#define ORGAN_SLOT_CYBERWARE_OS "cyberware_os"
/// Nervous-system choice, chest. Slipwire vs Dead Channel.
#define ORGAN_SLOT_CYBERWARE_NERVOUS "cyberware_nervous"
/// Environment ladder, chest. Second Wind -> Coolant Loops.
#define ORGAN_SLOT_CYBERWARE_SEAL "cyberware_seal"
/// Armor ladder, chest. Dermal Mesh -> Slabskin Plate.
#define ORGAN_SLOT_CYBERWARE_DERMAL "cyberware_dermal"
/// Blood filtration, chest. Hemoglass Filter.
#define ORGAN_SLOT_CYBERWARE_FILTER "cyberware_filter"
/// Hidden internal stash, chest. Cargo Cavity.
#define ORGAN_SLOT_CYBERWARE_STASH "cyberware_stash"
/// Auxiliary heart hardware, chest. Lazarus Node rides tg's HEART_AID
/// slot instead (it evicts the printable reviver); this slot is spare.
#define ORGAN_SLOT_CYBERWARE_HEART_AUX "cyberware_heart_aux"
/// Skeletal reinforcement, chest. Atlas Frame.
#define ORGAN_SLOT_CYBERWARE_FRAME "cyberware_frame"
/// Mobility ladder, legs. Shock Coils -> Hopper Pistons -> Meteor Piledriver.
#define ORGAN_SLOT_CYBERWARE_LEGS "cyberware_legs"
/// Vocal hardware, mouth. Currently unused (Voicebox Mimic cut in roster v2).
#define ORGAN_SLOT_CYBERWARE_LARYNX "cyberware_larynx"
/// Capacity governor, head. Governor Delete (+6 capacity).
#define ORGAN_SLOT_CYBERWARE_GOVERNOR "cyberware_governor"
/// Hand augmentation, arms. Gecko Grips vs Fixer's Fingers.
#define ORGAN_SLOT_CYBERWARE_HANDS "cyberware_hands"
/// Emissive circuit tattoos, chest. Chromatic Dermis.
#define ORGAN_SLOT_CYBERWARE_INK "cyberware_ink"
/// Digestive replacement, chest. Gastro Reactor.
#define ORGAN_SLOT_CYBERWARE_GUT "cyberware_gut"
/// Optical camo weave, chest. Ghostskin Weave.
#define ORGAN_SLOT_CYBERWARE_SKIN "cyberware_skin"
/// Aural hardware, ears. Heartbeat Doppler.
#define ORGAN_SLOT_CYBERWARE_EARS "cyberware_ears"
/// Pilot interface, head. Rigger Socket.
#define ORGAN_SLOT_CYBERWARE_RIGGER "cyberware_rigger"
/// Colonial Registry interface, head. Remote outpost management.
#define ORGAN_SLOT_CYBERWARE_REGISTRY "cyberware_registry"

// ---- Chrome read -------------------------------------------------------
// How much of a body's hardware a set of optics can resolve. Set per-optics
// with chrome_scan_resolution; the read itself lives in cyberware_scan.dm.

/// Street-tier resolution: signature count and total neural load, no names.
#define CYBERWARE_SCAN_SILHOUETTE 1
/// Pro-tier resolution: every unhidden ware named, with tier and condition.
#define CYBERWARE_SCAN_ITEMIZED 2

/// Held by a mob while optical camo is bending light around them. Granted by
/// the Ghostskin Weave with a source; NPC targeting refuses holders beyond
/// CYBERWARE_CAMO_SPOT_RANGE (cyberware_stealth.dm) and a chrome read on one
/// comes back as scatter (cyberware_scan.dm).
#define TRAIT_CYBER_CAMO "cyber_camo"

// ---- Tiers -------------------------------------------------------------

/// Street chrome: credits only, job-lube and fun utility.
#define CYBERWARE_TIER_1 1
/// Pro chrome: real capability adds.
#define CYBERWARE_TIER_2 2
/// Military chrome: playstyle-defining, voucher-priced.
#define CYBERWARE_TIER_3 3
/// Legend chrome: the chase.
#define CYBERWARE_TIER_4 4

// Tier accent colours: BIOS boot text, cradle UI load bar, sprite glow.
#define CYBERWARE_COLOR_TIER_1 "#ffb347"
#define CYBERWARE_COLOR_TIER_2 "#4dd8e6"
#define CYBERWARE_COLOR_TIER_3 "#ff2079"
#define CYBERWARE_COLOR_TIER_4 "#aaff3c"

// ---- Install / removal -------------------------------------------------

/// Chrome Cradle install sequence length (sedation runs slightly longer).
#define CYBERWARE_INSTALL_TIME (4 SECONDS)
/// Chrome Cradle removal sequence length.
#define CYBERWARE_REMOVAL_TIME (3 SECONDS)
/// Cradle tune-up fee, credits: clears EMP scramble and repairs installed chrome.
#define CYBERWARE_TUNEUP_FEE 200
/// How long an install context (surgery step start, Cradle sequence) stays
/// valid before Insert() stops honoring it. Generous enough to cover a slow
/// surgery tool's do_after; consumed on successful insert.
#define CYBERWARE_INSTALL_CONTEXT_WINDOW (30 SECONDS)
/// Base EMP downtime; divided by EMP severity (EMP_HEAVY = 1, EMP_LIGHT = 2),
/// matching the strongarm implant's 90/severity precedent.
#define CYBERWARE_EMP_DOWNTIME (9 SECONDS)
/// Gap between BIOS boot splash chat lines.
#define CYBERWARE_BOOT_LINE_DELAY (0.6 SECONDS)

// ---- Chromatic Dermis --------------------------------------------------
// Pulse strengths for cyberware_ink_pulse(). Any ware that does something
// worth looking at kicks the bearer's ink with one of these; the dermis is
// the framework's shared "your chrome just did a thing" tell.

/// A single soft swell: a stash swallowed, a tool folded out, a soft landing.
#define CYBERWARE_INK_SOFT 1
/// The double strobe: an ability fired, a fist landed, the grips clamping.
#define CYBERWARE_INK_HARD 2
/// A white-hot spike: a real hit taken, a chasm caught, a seal engaging.
#define CYBERWARE_INK_FLARE 3

// ---- Nightshade Optics -------------------------------------------------

/// Shortest gap between body-tag sweeps. The tags ride their target's loc so
/// they follow without help; only membership needs re-checking.
#define CYBERWARE_NIGHTSHADE_SWEEP (0.4 SECONDS)
/// Tag colour for a living body, and for a dead one.
#define CYBERWARE_NIGHTSHADE_LIVE_COLOR "#5cff9d"
#define CYBERWARE_NIGHTSHADE_DEAD_COLOR "#4a7f66"

// ---- Second Wind Bladder -----------------------------------------------

/// Reserve level below which the HUD alert goes amber and the bladder starts
/// warning its bearer out loud.
#define CYBERWARE_SECOND_WIND_LOW (45 SECONDS)
/// Alert category key for the engaged-bladder HUD indicator.
#define ALERT_CYBERWARE_SECOND_WIND "cyberware_second_wind"

/// Total breathable reserve, in deciseconds of breathing covered.
#define CYBERWARE_SECOND_WIND_RESERVE (180 SECONDS)
/// Reserve spent per blocked breath. Carbons draw one breath roughly every
/// 8 seconds of life ticks, so each engaged breath costs that much reserve.
#define CYBERWARE_SECOND_WIND_DRAIN (8 SECONDS)
/// Reserve regained per normal breath in breathable air, twice the drain
/// rate, so a full recharge takes half as long as the reserve lasted.
#define CYBERWARE_SECOND_WIND_REFILL (16 SECONDS)
/// Minimum environmental O2 partial pressure (kPa) the bladder considers
/// breathable, mirroring the lungs' safe_oxygen_min of 16.
#define CYBERWARE_BREATHABLE_O2_KPA 16
