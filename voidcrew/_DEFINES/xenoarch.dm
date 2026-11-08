// Xenoarchaeology: shared defines for every part of voidcrew/modules/xenoarch/.
// Each section names the part that owns its numbers. Parts may add part-local defines at
// the top of their own files; anything two parts read belongs here.
//
// Unit tests compile before this file and cannot see these defines (see the test files for
// the literal values they mirror).

// ===== Bands (shared) =====
// A find's band is the ZONE_* it was dug in (voidcrew/_DEFINES/overmap_zones.dm), stamped on
// the find. Price and research read the stamp, never where the find is now. A null stamp
// means "not dug": buyers refuse it.

/// Positional lists below are indexed by ZONE_GREEN (1), ZONE_YELLOW (2), ZONE_RED (3).
#define XENOARCH_BAND_INDEX(band) clamp(band || ZONE_GREEN, ZONE_GREEN, ZONE_RED)

// ===== Effect tiers (core) =====
// Numeric so they index the positional lists below. Never use them as assoc keys.
#define ARTIFACT_TIER_COMMON 1
#define ARTIFACT_TIER_UNCOMMON 2
#define ARTIFACT_TIER_RARE 3
#define ARTIFACT_TIER_EXTREME 4

/// Main-effect tier odds for a large artifact, per band: common, uncommon, rare, extreme.
#define ARTIFACT_TIER_ODDS_GREEN list(62, 28, 9, 1)
#define ARTIFACT_TIER_ODDS_YELLOW list(45, 33, 18, 4)
#define ARTIFACT_TIER_ODDS_RED list(30, 34, 27, 9)

/// Chance a large artifact also carries a minor second effect.
#define ARTIFACT_SECOND_EFFECT_CHANCE 50

// ===== Effect strength (core) =====
#define ARTIFACT_STRENGTH_SMALL "small"
#define ARTIFACT_STRENGTH_MEDIUM "medium"
#define ARTIFACT_STRENGTH_LARGE "large"
/// Strength weights per band (small, medium, large): green leans small, red leans large.
#define ARTIFACT_STRENGTH_ODDS_GREEN list(60, 30, 10)
#define ARTIFACT_STRENGTH_ODDS_YELLOW list(35, 45, 20)
#define ARTIFACT_STRENGTH_ODDS_RED list(15, 45, 40)

// ===== Release modes (core) =====
// What the analyser reports as "contact", "field" or "bursts".
#define ARTIFACT_RELEASE_TOUCH "touch"
#define ARTIFACT_RELEASE_AURA "aura"
#define ARTIFACT_RELEASE_PULSE "pulse"
#define ARTIFACT_ALL_RELEASE_METHODS list(ARTIFACT_RELEASE_TOUCH, ARTIFACT_RELEASE_AURA, ARTIFACT_RELEASE_PULSE)

// ===== Charge (core) =====
// Per second. Auras spend three times what the artifact refills, so a bolted aura runs about
// a third of the time. A pulse fires when the store is full and empties it.
#define ARTIFACT_RECHARGE_PER_SECOND 0.5
#define ARTIFACT_AURA_COST_PER_SECOND 1.5
#define ARTIFACT_TOUCH_COST 3

// ===== Triggers (core) =====
// Bitflags so an effect can hold one and a check can test several. Oxygen and nitrogen
// triggers from Nova are deliberately gone: ship air would keep those artifacts always on.
#define ARTIFACT_TRIGGER_TOUCH (1<<0)
#define ARTIFACT_TRIGGER_WATER (1<<1)
#define ARTIFACT_TRIGGER_ACID (1<<2)
#define ARTIFACT_TRIGGER_VOLATILE (1<<3)
#define ARTIFACT_TRIGGER_TOXIN (1<<4)
#define ARTIFACT_TRIGGER_IMPACT (1<<5)
#define ARTIFACT_TRIGGER_ENERGY (1<<6)
#define ARTIFACT_TRIGGER_HEAT (1<<7)
#define ARTIFACT_TRIGGER_COLD (1<<8)
#define ARTIFACT_TRIGGER_PLASMA (1<<9)
#define ARTIFACT_TRIGGER_CO2 (1<<10)
#define ARTIFACT_TRIGGER_PROXIMITY (1<<11)

/// Triggers read from the air on the artifact's tile every process.
#define ARTIFACT_TRIGGERS_AIR (ARTIFACT_TRIGGER_HEAT | ARTIFACT_TRIGGER_COLD | ARTIFACT_TRIGGER_PLASMA | ARTIFACT_TRIGGER_CO2)
/// Triggers held for as long as a condition lasts, rather than woken by a stimulus.
#define ARTIFACT_TRIGGERS_LEVEL (ARTIFACT_TRIGGERS_AIR | ARTIFACT_TRIGGER_PROXIMITY)

/// Every trigger an effect may roll. Weights are in artifact_trigger_weight().
#define ARTIFACT_ALL_TRIGGERS list(\
	ARTIFACT_TRIGGER_TOUCH,\
	ARTIFACT_TRIGGER_WATER,\
	ARTIFACT_TRIGGER_ACID,\
	ARTIFACT_TRIGGER_VOLATILE,\
	ARTIFACT_TRIGGER_TOXIN,\
	ARTIFACT_TRIGGER_IMPACT,\
	ARTIFACT_TRIGGER_ENERGY,\
	ARTIFACT_TRIGGER_HEAT,\
	ARTIFACT_TRIGGER_COLD,\
	ARTIFACT_TRIGGER_PLASMA,\
	ARTIFACT_TRIGGER_CO2,\
	ARTIFACT_TRIGGER_PROXIMITY,\
)

// Trigger thresholds (Nova's values).
#define ARTIFACT_HEAT_AIR_KELVIN 375
#define ARTIFACT_HEAT_TOOL_KELVIN 700
#define ARTIFACT_COLD_AIR_KELVIN 225
#define ARTIFACT_GAS_TRIGGER_MOLES 10
#define ARTIFACT_PROXIMITY_RANGE 3
#define ARTIFACT_IMPACT_THROWFORCE 10

// Trigger families, as the analyser reports them.
#define ARTIFACT_FAMILY_CONTACT "contact"
#define ARTIFACT_FAMILY_ENERGY "energy"
#define ARTIFACT_FAMILY_AIR "air"

// ===== Waking (core) =====
/// How long a contact stimulus keeps an effect awake. Each artifact rolls once in this range;
/// another stimulus while awake starts the count again.
#define ARTIFACT_WAKE_MIN (45 SECONDS)
#define ARTIFACT_WAKE_MAX (90 SECONDS)
/// How long a level trigger keeps an effect awake after its condition ends.
#define ARTIFACT_LEVEL_LINGER (6 SECONDS)
/// Hauling, bumping and repeated pats count as one touch per this long.
#define ARTIFACT_TOUCH_COOLDOWN (3 SECONDS)

// ===== Energy kinds (core) =====
// Nova's seven type_name values. Several effects share each kind, so the analyser narrows
// an artifact down without naming its effect. Keys index GLOB.artifact_energy_kinds.
#define ARTIFACT_ENERGY_CONCENTRATED "concentrated"
#define ARTIFACT_ENERGY_PSIONIC "psionic"
#define ARTIFACT_ENERGY_ELECTROMAGNETIC "electromagnetic"
#define ARTIFACT_ENERGY_PARTICLE "particle"
#define ARTIFACT_ENERGY_ORGANIC "organic"
#define ARTIFACT_ENERGY_BLUESPACE "bluespace"
#define ARTIFACT_ENERGY_SYNTHESIS "synthesis"

// ===== Labels (core vocabulary; the labeler is P3) =====
/// The second-effect field when the labeller thinks there is none. A correct "None" counts.
#define ARTIFACT_LABEL_NONE "None"

// ===== Scan and harvest lock (core API; analyser P3, harvester P4) =====
/// A lock nobody released frees itself after this long.
#define ARTIFACT_LOCK_TIMEOUT (2 MINUTES)

// ===== Harvesting (P4 owns the machines) =====
#define ARTIFACT_MAX_HARVESTS 3
/// Charge an exotic battery holds. One harvest fills one battery.
#define ARTIFACT_BATTERY_CAPACITY 200
/// Charge per second a harvester draws on tier-1 capacitors: a full battery in 80 seconds.
#define ARTIFACT_HARVEST_DRAW_RATE 2.5
/// Charge per second a utilizer spends running a field or bursts: a full battery lasts 400 seconds.
#define ARTIFACT_UTILIZER_DRAIN 0.5
/// Charge per second a utilizer feeds a burst effect's store, twice what an artifact refills.
#define ARTIFACT_UTILIZER_PULSE_FEED 1
/// Charge one contact use costs: ten from a full battery.
#define ARTIFACT_UTILIZER_TOUCH_COST 20

// ===== Pricing (core function; buyers are P5) =====
/// Base price of a large artifact by stamped band (green, yellow, red).
#define ARTIFACT_PRICE_BASE list(250, 450, 700)
/// Main-effect tier multiplier (common, uncommon, rare, extreme).
#define ARTIFACT_PRICE_TIER_MULT list(1, 1.5, 2.5, 4)
/// Label accuracy shares. A label pays its share at or above the floor, else the unlabelled rate.
#define ARTIFACT_LABEL_SHARE_EFFECT 0.5
#define ARTIFACT_LABEL_SHARE_TRIGGER 0.3
#define ARTIFACT_LABEL_SHARE_SECOND 0.2
#define ARTIFACT_LABEL_ACCURACY_FLOOR 0.5
#define ARTIFACT_UNLABELLED_SHARE 0.2
#define ARTIFACT_DAMAGED_MULT 0.5
#define ARTIFACT_HARVEST_MULT 0.8
/// Receipts round to this many credits.
#define ARTIFACT_PRICE_ROUNDING 5

// ===== Research (core function; payout is P3) =====
/// First full analysis of a large artifact, by stamped band (green, yellow, red).
#define ARTIFACT_RESEARCH_POINTS list(100, 150, 250)
/// Multiplier for a rare or extreme main effect.
#define ARTIFACT_RESEARCH_RARE_MULT 1.5

// ===== Dig sites (P2) =====
#define XENOARCH_SITES_PER_PLANET 3
/// Large and small finds per site, by band (green, yellow, red).
#define XENOARCH_LARGE_PER_SITE list(1, 1, 2)
#define XENOARCH_SMALL_PER_SITE list(3, 3, 2)
/// Small-find tier odds per band: tier 1, 2, 3.
#define XENOARCH_SMALL_TIER_ODDS_GREEN list(60, 32, 8)
#define XENOARCH_SMALL_TIER_ODDS_YELLOW list(50, 37, 13)
#define XENOARCH_SMALL_TIER_ODDS_RED list(40, 40, 20)
/// Chance that uncovering a large find wakes local fauna, by band.
#define XENOARCH_AMBUSH_CHANCE list(0, 25, 45)
/// Minimum tiles between two dig sites.
#define XENOARCH_SITE_SPACING 20

// ===== Signals =====
// All sent on the artifact (/obj/machinery/artifact) unless noted.

/// An effect woke: (datum/artifact_effect/effect)
#define COMSIG_ARTIFACT_EFFECT_ACTIVATED "artifact_effect_activated"
/// An effect went dormant: (datum/artifact_effect/effect)
#define COMSIG_ARTIFACT_EFFECT_DEACTIVATED "artifact_effect_deactivated"
/// A stimulus reached the artifact, whether or not anything woke: (trigger, mob/living/user, woke)
#define COMSIG_ARTIFACT_STIMULATED "artifact_stimulated"
/// A label was stuck on or scraped off: (datum/artifact_label/label_or_null, mob/user)
#define COMSIG_ARTIFACT_LABEL_CHANGED "artifact_label_changed"
/// The artifact was stamped as dug: (band)
#define COMSIG_ARTIFACT_STAMPED "artifact_stamped"
/// One harvest was taken from it (P4 sends): (datum/artifact_effect/effect, mob/user)
#define COMSIG_ARTIFACT_HARVESTED "artifact_harvested"
/// It was sold (P5 sends, on the artifact before it is deleted): (credits, vouchers, mob/seller)
#define COMSIG_ARTIFACT_SOLD "artifact_sold"

// ===== Metrics (record_metric events) =====
// Category in brackets. Event names must never equal a record_metric() parameter name.
/// [METRIC_RESEARCH] a find came out of the ground. subject = find type, zone = band.
#define XENOARCH_METRIC_DUG "artifact_dug"
/// [METRIC_RESEARCH] a find crumbled or came out unstabilised.
#define XENOARCH_METRIC_LOST "artifact_lost"
/// [METRIC_RESEARCH] first full analysis paid. points = research points.
#define XENOARCH_METRIC_ANALYSED "artifact_analysed"
/// [METRIC_RESEARCH] an effect was drained into a battery.
#define XENOARCH_METRIC_HARVESTED "artifact_harvested"
/// [METRIC_TRADE] sold at an outpost. credits, vouchers; details: accuracy, tier, band, harvests, damaged.
#define XENOARCH_METRIC_SOLD "artifact_sold"
