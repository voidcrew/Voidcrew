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
/// Fractional on purpose, it must never collide with a real layer index, nor
/// with a fresh stump (HV_STUMP_FRESH_LAYER, 27.5).
#define CYBERWARE_WORN_LAYER 27.6
/// Mob layer the lit nodes of a spine rig (Cascade, Redline) shine at: just over
/// whatever is worn on the back (BACK_LAYER 14, and every suit and cloak under
/// it), still under hair (HAIR_LAYER 13) and headgear. Only what glows goes up
/// here; the housing and dark nodes stay at CYBERWARE_WORN_LAYER.
#define CYBERWARE_SPINE_SHINE_LAYER 13.7

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
// nothing on the map.

/// Held by a bearer while their chrome optics are zoomed. Source is the optics.
#define TRAIT_CYBER_ZOOMED "cyber_zoomed"

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

/// Sockets: where a ware's chips sit on the ring. Each owns a run of fixed
/// positions on its region's arc, so one socket's chrome changing never moves
/// another socket's chips. Hand chrome rides its arm's socket.
#define CHROME_WHEEL_SOCKET_EYES "eyes"
#define CHROME_WHEEL_SOCKET_HEAD "head"
#define CHROME_WHEEL_SOCKET_OS "os"
#define CHROME_WHEEL_SOCKET_SKIN "skin"
#define CHROME_WHEEL_SOCKET_LEFT_ARM "l_arm"
#define CHROME_WHEEL_SOCKET_RIGHT_ARM "r_arm"
#define CHROME_WHEEL_SOCKET_LEGS "legs"

/// Radius in pixels of the ring the chips sit on.
#define CHROME_WHEEL_RADIUS 100
/// Degrees between neighbouring chips on the ring.
#define CHROME_WHEEL_STEP 14.5
/// A socket with more chips than its arc holds starts another row this much
/// further out, at the same angles.
#define CHROME_WHEEL_ROW_GAP 26
/// The ring's centre sits this many pixels above the centre of the view.
#define CHROME_WHEEL_CENTRE_Y 2
/// Mouse distance from the ring centre inside which nothing is pointed at.
#define CHROME_WHEEL_DEADZONE 34
/// A chip this close to the mouse is the one under it.
#define CHROME_WHEEL_PICK_RANGE 12
/// Otherwise the mouse points at the first-row chip whose bearing from the ring
/// centre is nearest its own, if one lies within this many degrees.
#define CHROME_WHEEL_POINT_TOLERANCE 13

/// After a pick the wheel stays up this long for the lock and fade. The pick
/// itself lands at once.
#define CHROME_WHEEL_LINGER_TIME (0.2 SECONDS)
/// A wheel opened from the Chrome button fires what a click picks, so a click
/// further than this from the ring's centre picks by bearing no more: out past
/// the second row, a click just shuts the wheel.
#define CHROME_WHEEL_FIRE_REACH (CHROME_WHEEL_RADIUS + CHROME_WHEEL_ROW_GAP + 24)
/// Reserves Arm chrome's place on the wheel (GLOB.chrome_wheel_reserved), as an
/// organ slot reserves its ware's.
#define CHROME_WHEEL_ARMS_KEY "chrome_arms"
/// The region an Arm chrome chip lights: both arms.
#define CHROME_WHEEL_REGION_ARMS "arms"
/// The Chrome button's and Arm chrome's own art.
#define CHROME_HUD_ICON 'voidcrew/modules/cyberware/icons/chrome_hud.dmi'

#define CHROME_WHEEL_ICON 'voidcrew/modules/cyberware/icons/chrome_wheel.dmi'
/// 240x240 art centred on the ring: body, arcs, leaders, glows, backdrop.
#define CHROME_WHEEL_RING_ICON 'voidcrew/modules/cyberware/icons/chrome_wheel_ring.dmi'
/// Corner brackets borrowed from the chrome read.
#define CHROME_WHEEL_BRACKET_ICON 'voidcrew/modules/cyberware/icons/chrome_read.dmi'

/// Wheel colours, the chrome read's own.
#define CHROME_WHEEL_HUD_COLOR CYBERWARE_COLOR_TIER_2
#define CHROME_WHEEL_PANEL_COLOR "#060e12"
#define CHROME_WHEEL_NAME_COLOR "#e6fbff"
#define CHROME_WHEEL_DIM_COLOR "#8fa1a8"
#define CHROME_WHEEL_OFFLINE_COLOR "#ff5a4a"
#define CHROME_WHEEL_OFFLINE_NAME_COLOR "#7d8a90"
/// The pick's brackets (radial.dmi's module_selected cyan).
#define CHROME_WHEEL_PICKED_COLOR "#00ffff"
/// Deployed or armed (radial.dmi's module_active green).
#define CHROME_WHEEL_DEPLOYED_COLOR "#00ff00"

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
