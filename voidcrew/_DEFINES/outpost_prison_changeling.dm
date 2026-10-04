// ===== OUTPOST PRISON: THE CHANGELING EXPERIMENT (see outpost_prison_changeling.dm) =====
// The specimen host, the headslug and its vents, and the horror it grows into. Numbers from the
// prison balance spec, section 9. Seconds unless a value says otherwise.

/// Other code can test for the changeling experiment's API with #ifdef. Keep it defined.
#define OUTPOST_CHANGELING_API

// ----- the host -----
/// Seconds from eating the specimen to the burst, rolled in this range
#define OUTPOST_CHANGELING_INCUBATION_MIN 90
#define OUTPOST_CHANGELING_INCUBATION_MAX 120
/// Seconds into incubation of the first stomach complaint, and of the coughing and retching
#define OUTPOST_CHANGELING_TELL_PAIN 30
#define OUTPOST_CHANGELING_TELL_RETCH 60
/// Seconds before the burst that the host takes to their bed
#define OUTPOST_CHANGELING_BED_WARNING 22.5
/// Seconds the host has to get to their bed before they go down where they are
#define OUTPOST_CHANGELING_BED_WALK 15
/// Seconds a host killed before the burst takes to burst anyway
#define OUTPOST_CHANGELING_EARLY_BURST 3
/// Seconds a host may spend out of the cell block before the specimen is lost
#define OUTPOST_CHANGELING_HOST_LOST_AFTER 60
/// The host's sentence is held at least this long, so they are not released mid-incubation
#define OUTPOST_CHANGELING_HOST_SENTENCE_HOLD 600

// ----- the headslug -----
#define OUTPOST_HEADSLUG_HEALTH 50
#define OUTPOST_HEADSLUG_SPEED 1.5
/// How long slipping into a vent takes; any damage interrupts it
#define OUTPOST_HEADSLUG_VENT_ENTRY (2 SECONDS)
/// Seconds after the burst the slug looks for a vent before it gives up and fights
#define OUTPOST_HEADSLUG_SEEK_TIME 30
/// How long a slug wrenched out of a vent is stunned
#define OUTPOST_HEADSLUG_WRENCHED_STUN (1 SECONDS)

// ----- the vents -----
/// How long unbolting a sealed vent's cover takes
#define OUTPOST_KESSLER_VENT_WRENCH_TIME (3 SECONDS)
/// Seconds in the vents before the horror comes out
#define OUTPOST_CHANGELING_VENT_TIME 90
/// Seconds the emergence vent strains before it gives
#define OUTPOST_CHANGELING_STRAIN_TIME 5
/// Seconds between rattles of the occupied vent
#define OUTPOST_CHANGELING_RATTLE_GAP 4
/// Seconds in the vents at which the second and third noise phases start
#define OUTPOST_CHANGELING_NOISE_LOUDER 30
#define OUTPOST_CHANGELING_NOISE_VIOLENT 60
/// Seconds between prisoners' remarks about the noise
#define OUTPOST_CHANGELING_REMARK_GAP 12

// ----- the horror -----
#define OUTPOST_HORROR_BASE_HEALTH 400
/// More health per living player on the level beyond the first, at emergence, up to the cap
#define OUTPOST_HORROR_HEALTH_PER_PLAYER 100
#define OUTPOST_HORROR_EXTRA_PLAYERS_MAX 3
/// Brute and burn damage it takes per point dealt: the chitin turns some of it
#define OUTPOST_HORROR_DAMAGE_COEFF 0.85
/// Fire hurts it this many times over, standing or down (burning only; lasers and other burns take OUTPOST_HORROR_DAMAGE_COEFF)
#define OUTPOST_HORROR_FIRE_MULT 2
/// Burn damage a second it takes on fire while standing, before OUTPOST_HORROR_FIRE_MULT
#define OUTPOST_HORROR_FIRE_DAMAGE 5
/// Fire stacks it loses a second (basic mobs lose 5, so a lick of flame goes out before it burns)
#define OUTPOST_HORROR_FIRE_DECAY -1
/// Its burning is the crew's for the containment bonus: whoever lit it, else whoever hurt it or aimed fire at it within this long
#define OUTPOST_HORROR_FIRE_CREDIT_WINDOW (30 SECONDS)
/// A flamethrower aimed at it this recently lit it, if it catches fire now
#define OUTPOST_HORROR_FIRE_AIM_WINDOW (3 SECONDS)
#define OUTPOST_HORROR_SPEED 2
/// The arm blade
#define OUTPOST_HORROR_BLADE_DAMAGE 22
#define OUTPOST_HORROR_BLADE_COOLDOWN (1.6 SECONDS)
#define OUTPOST_HORROR_BLADE_AP 10
/// Percent chance the shield turns aside a hit from within OUTPOST_HORROR_SHIELD_ARC degrees of where it faces
#define OUTPOST_HORROR_SHIELD_CHANCE 25
#define OUTPOST_HORROR_SHIELD_ARC 45
/// The least time between any two of its abilities
#define OUTPOST_HORROR_ABILITY_GAP (5 SECONDS)
/// It cannot act while it unfolds from the vent
#define OUTPOST_HORROR_UNFOLD_TIME (2 SECONDS)
/// It grows this much bigger with every absorb
#define OUTPOST_HORROR_SIZE_PER_ABSORB 0.05

#define OUTPOST_HORROR_RESONANT_WINDUP (1.5 SECONDS)
#define OUTPOST_HORROR_RESONANT_RADIUS 4
#define OUTPOST_HORROR_RESONANT_CONFUSION (5 SECONDS)
#define OUTPOST_HORROR_RESONANT_JITTER (10 SECONDS)
#define OUTPOST_HORROR_RESONANT_COOLDOWN (20 SECONDS)

#define OUTPOST_HORROR_DISSONANT_WINDUP (2 SECONDS)
#define OUTPOST_HORROR_DISSONANT_RADIUS 3
/// Share of an energy weapon's full charge the dissonant shriek drains
#define OUTPOST_HORROR_DISSONANT_DRAIN 0.3
#define OUTPOST_HORROR_DISSONANT_HEADSET_TIME (10 SECONDS)
#define OUTPOST_HORROR_DISSONANT_LIGHT_RADIUS 5
#define OUTPOST_HORROR_DISSONANT_COOLDOWN (24 SECONDS)

/// Fleshmend: only below this share of its health; heals FLESHMEND_HEAL a second for FLESHMEND_TIME seconds
#define OUTPOST_HORROR_FLESHMEND_BELOW 0.6
#define OUTPOST_HORROR_FLESHMEND_TIME 8
#define OUTPOST_HORROR_FLESHMEND_HEAL 10
/// Damage taken while mending is multiplied by this
#define OUTPOST_HORROR_FLESHMEND_VULNERABILITY 1.25
/// Damage in one mend that breaks it
#define OUTPOST_HORROR_FLESHMEND_BREAK 45
#define OUTPOST_HORROR_FLESHMEND_STAGGER (1 SECONDS)
#define OUTPOST_HORROR_FLESHMEND_COOLDOWN (35 SECONDS)

#define OUTPOST_HORROR_TENTACLE_WINDUP (1 SECONDS)
#define OUTPOST_HORROR_TENTACLE_RANGE 7
#define OUTPOST_HORROR_TENTACLE_DAMAGE 22
#define OUTPOST_HORROR_TENTACLE_KNOCKDOWN (1 SECONDS)
#define OUTPOST_HORROR_TENTACLE_COOLDOWN (14 SECONDS)

/// Absorb: the proboscis beat and the drained beat, from the grab
#define OUTPOST_HORROR_ABSORB_PROBOSCIS (4 SECONDS)
#define OUTPOST_HORROR_ABSORB_TIME (10 SECONDS)
/// Damage during one absorb that breaks it
#define OUTPOST_HORROR_ABSORB_BREAK 40
#define OUTPOST_HORROR_ABSORB_STAGGER (1.5 SECONDS)
#define OUTPOST_HORROR_ABSORB_COOLDOWN (20 SECONDS)
/// How long it stands still after an absorb
#define OUTPOST_HORROR_DIGEST_TIME (2 SECONDS)
/// It goes for a body this close, when hurt below ABSORB_HURT_BELOW or with no player within ABSORB_CLEAR_RANGE
#define OUTPOST_HORROR_ABSORB_RANGE 4
#define OUTPOST_HORROR_ABSORB_HURT_BELOW 0.75
#define OUTPOST_HORROR_ABSORB_CLEAR_RANGE 3

/// Prying an airlock that will not open for it, and one that is bolted, welded or unpowered
#define OUTPOST_HORROR_PRY_TIME (4 SECONDS)
#define OUTPOST_HORROR_PRY_BOLTED_TIME (8 SECONDS)
/// Blows it takes to break an interior window
#define OUTPOST_HORROR_WINDOW_HITS 3
/// Kept from its quarry this long, it breaks through toward them
#define OUTPOST_HORROR_BREACH_AFTER (4 SECONDS)

/// A dead slug or horror is collected this long after it dies
#define OUTPOST_CHANGELING_REMAINS_TIME (10 SECONDS)

// ----- the horror's regeneration -----
// At 0 health it goes down regenerating instead of dying, vented rooms included. It dies for good
// when its body is destroyed, gibbed or dusted, when its body is put out into open space off the
// outpost while it is down, or when an admin kills it.
/// Seconds it stays down before it gets up again; they count only while a member of the wing is home
#define OUTPOST_HORROR_REGEN_TIME 45
/// Share of its health it gets up with
#define OUTPOST_HORROR_REGEN_HEALTH 0.5
/// Seconds before it gets up that it starts pushing itself up, as a warning
#define OUTPOST_HORROR_RISE_WARNING 5
/// Damage its body can take while it is down before it bursts, dead for good
#define OUTPOST_HORROR_REMAINS 200
/// Burn damage a second fire does to its body while it is down, before OUTPOST_HORROR_FIRE_MULT doubles it
#define OUTPOST_HORROR_REMAINS_BURN 10

// ----- afterwards -----
/// Mood each prisoner who saw a death loses when the experiment ends
#define OUTPOST_CHANGELING_WITNESS_MOOD 10
/// Tension each prisoner the creature killed adds when the experiment ends
#define OUTPOST_CHANGELING_KILL_TENSION 15
