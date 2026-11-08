// Cyberware: chrome load, slots, tiers, Cradle timings (voidcrew/modules/cyberware/)

/// Baseline chrome capacity of a carbon body. Installed ware sums its
/// chrome_load against this; the Overclock Governor raises it via the
/// component's capacity_bonus hook. Going over doesn't block removal,
/// it browns every piece of chrome out until the load drops back under.
#define CYBERWARE_BASE_CAPACITY 20

/// Mob-overlay height worn chrome draws at: just over the jumpsuit
/// (UNIFORM_LAYER, 28) and under the worn ID (ID_LAYER, 27), so arm plates and
/// a spine rig read over normal clothes while hands (BODYPARTS_HIGH_LAYER 25),
/// gloves, shoes and every suit, vest or armour layer (SUIT_LAYER 19 and up)
/// still cover them. Mob layers count down: a lower number draws on top.
/// Fractional on purpose, it must never collide with a real layer index.
#define CYBERWARE_WORN_LAYER 27.5

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

// ---- Optics zoom (cyberware_zoom.dm) -----------------------------------
// Every set of chrome optics can zoom: tg's scope component pans the camera
// toward the cursor. A zoomed bearer can't fire a gun and their clicks reach
// nothing on the map, except a cyberdeck through the signal below.

/// Held by a bearer while their chrome optics are zoomed. Source is the optics.
#define TRAIT_CYBER_ZOOMED "cyber_zoomed"

/**
 * Sent on a zoomed bearer when they click the zoomed view, instead of the click
 * going anywhere else: (atom/target, list/modifiers). [target] is the best atom
 * on the turf under the cursor, the one a scoped gun would shoot (a mob, then a
 * dense object, then any other object, else the turf itself). [modifiers] is
 * the click's params2list(). Nothing checks range or line of sight first, so a
 * listener that acts on [target] has to.
 *
 * Zoomed clicks never reach click intercepts, so an armed click-to-activate
 * action does not see them. A listener that handles one (a cyberdeck firing its
 * armed hack) returns COMPONENT_CYBERWARE_ZOOM_CLICK_HANDLED and disarms itself.
 * Unhandled, the click is dropped: zoom is look-only.
 */
#define COMSIG_CYBERWARE_ZOOM_CLICK "cyberware_zoom_click"
	/// Returned by a COMSIG_CYBERWARE_ZOOM_CLICK listener that acted on the click.
	#define COMPONENT_CYBERWARE_ZOOM_CLICK_HANDLED (1<<0)

// ---- Chrome wheel (chrome_wheel.dm) ------------------------------------

/// Name of the "Chrome wheel" keybind; the release poll reads the player's
/// keys for it to catch modifier binds, which never get a keyUp of their own.
#define CHROME_WHEEL_KEYBIND "chrome_wheel"
/// A wheel key let go sooner than this was a tap, and the wheel stays open
/// for a click instead of closing on release.
#define CHROME_WHEEL_HOLD_TIME (0.3 SECONDS)

/// Wheel states. CLOSED, HELD (open while the key is down) or CLICK (open
/// after a tap, until the next click or press).
#define CHROME_WHEEL_CLOSED 0
#define CHROME_WHEEL_HELD 1
#define CHROME_WHEEL_CLICK 2

/// Body regions. Each owns fixed slice positions, so one region's chrome
/// changing never moves another region's slices.
#define CHROME_WHEEL_HEAD "head"
#define CHROME_WHEEL_RIGHT_ARM "right_arm"
#define CHROME_WHEEL_LEFT_ARM "left_arm"
#define CHROME_WHEEL_LEGS "legs"
#define CHROME_WHEEL_TORSO "torso"

/// Radius in pixels of the torso ring around the centre. The OS slot sits at
/// its top.
#define CHROME_WHEEL_INNER_RADIUS 40
/// Radius of the outer ring, which holds the head (top), right arm (right),
/// legs (bottom) and left arm (left), three positions each, 30 degrees apart.
#define CHROME_WHEEL_OUTER_RADIUS 72
/// Distance between rows: a region's fourth slice and on, and the sub-option
/// ring outside everything.
#define CHROME_WHEEL_ROW_GAP 38
/// Centre-to-centre spacing of sub-option slices along their ring.
#define CHROME_WHEEL_SLICE_SPACING 37
/// Mouse distance from the centre inside which nothing is pointed at.
#define CHROME_WHEEL_DEADZONE 16
/// A slice this close to the mouse is the one under it.
#define CHROME_WHEEL_PICK_RANGE 28
/// Past the slices, the mouse points at whichever slice lies within this many
/// degrees of its direction.
#define CHROME_WHEEL_POINT_TOLERANCE 20

// ---- Phase 2 models: seal, frame and nervous street models -------------
// ware_models_b.dm. Hardweave, the Strut frame, the Deep-lung bladder, the
// Heat-sink and Frostline linings, the Twitchwire and Weaver shunts, and the
// Thumper ear.

/// Held by a bearer whose skeleton simply does not break. Blocks the whole
/// bone wound series, dislocations, hairline fractures, compound fractures,
/// at the wound system's own gate, and nothing else. Every other wound series
/// lands on its bearer exactly as it lands on anyone. Granted by the Atlas
/// frame (ware_military_body.dm) and the Strut frame (ware_models_b.dm); the
/// gate itself is in ware_military_body.dm.
#define TRAIT_CYBERWARE_UNBREAKABLE_BONES "cyberware_unbreakable_bones"
