// # Bounty hunting: identity defines
//
// Owner: P1 identity (voidcrew/modules/bounties/bounty_identity.dm, bounty_looks.dm and
// strings/bounty_criminals.json). Only P1 edits this file. The shared enums are in bounties.dm.
//
// Unit tests compile before this file: they use the literal values, with the define named in a
// comment.

// ===== DIALOGUE =====

/// The criminals' dialogue file: lines by context, crimes by tier, aliases and feature wording
#define BOUNTY_IDENTITY_STRINGS_FILE "bounty_criminals.json"
/// Where it lives
#define BOUNTY_IDENTITY_STRINGS_DIR "voidcrew/modules/bounties/strings"
/// A mob says at most one bounty line per this long, unless the line is forced
#define BOUNTY_SAY_COOLDOWN (8 SECONDS)
/// A mob doesn't say the same line again within this long (a forced line may, when every line of its context is used up)
#define BOUNTY_SAY_NO_REPEAT (60 SECONDS)
/// Percent chance a speaker with a voice (meek, normal, boss) picks from its own lines before the shared ones
#define BOUNTY_SAY_VOICE_CHANCE 60

// ===== ARCHETYPE ROLLS (spec section 2) =====

/// Percent of Petty criminals who are meek; the rest are normal
#define BOUNTY_PETTY_MEEK_CHANCE 70
/// Percent of Wanted criminals who are meek; the rest are normal
#define BOUNTY_WANTED_MEEK_CHANCE 30

// ===== DISTINGUISHING FEATURES =====
// The keys of /datum/bounty_record's features list. Each value is the text examine prints after the
// feature's label, so two records share a feature when the key and the text are both the same.

/// Hair shape and colour, from the current look: "long, black". Only species whose hair has its own colour.
#define BOUNTY_FEATURE_HAIR "hair"
/// A scar on the face or a hand: "across the left cheek"
#define BOUNTY_FEATURE_SCAR "scar"
/// A tattoo on an arm or the neck: "an anchor on the left forearm"
#define BOUNTY_FEATURE_TATTOO "tattoo"
/// A coloured scarf, worn over the outfit when it leaves the neck free: "a red scarf"
#define BOUNTY_FEATURE_CLOTHING "clothing"
/// How they walk: "limps on the left leg"
#define BOUNTY_FEATURE_LIMP "limp"
/// Glasses or an eyepatch, worn when the outfit leaves the eyes free: "round glasses"
#define BOUNTY_FEATURE_GLASSES "glasses"
/// A missing or damaged ear: "the left ear is missing"
#define BOUNTY_FEATURE_EAR "missing_ear"

/// Fewest distinguishing features a record gets
#define BOUNTY_FEATURES_MIN 2
/// Most distinguishing features a record gets
#define BOUNTY_FEATURES_MAX 3

// ===== LOOKS =====

/// Chance a man's look has a beard or moustache, for species with facial hair
#define BOUNTY_FACIAL_HAIR_CHANCE 55
/// Most built looks (record and outfit) kept at once; the oldest go first
#define BOUNTY_LOOK_CACHE_MAX 64
/// Most hair re-rolls for an old look or a decoy to find hair that matches nothing it must not match
#define BOUNTY_HAIR_ROLL_ATTEMPTS 50

// ===== MUGSHOTS =====
// Head and shoulders out of a 32x32 front view (BYOND icon coordinates: 1,1 is the bottom left).

#define BOUNTY_MUGSHOT_X1 9
#define BOUNTY_MUGSHOT_Y1 17
#define BOUNTY_MUGSHOT_X2 24
#define BOUNTY_MUGSHOT_Y2 32
/// How much the cropped portrait is scaled up, so it reads without CSS pixel scaling
#define BOUNTY_MUGSHOT_SCALE 4
/// The wall behind them
#define BOUNTY_MUGSHOT_BACKDROP "#b9c0c7"
/// The height lines on the wall
#define BOUNTY_MUGSHOT_LINES "#949da6"

// ===== SIGNALS =====

/// Sent on a /datum/bounty_record when its mugshot has been built and cached on record.mugshot: ()
#define COMSIG_BOUNTY_RECORD_MUGSHOT_READY "bounty_record_mugshot_ready"
