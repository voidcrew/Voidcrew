// Outpost police (voidcrew/modules/outpost_police/). Owner: P0 seams, frozen: packages never edit this file.
// Unit tests are compiled before this file, so a test uses the literal value with a comment naming the define.

// ===== WANTED LEVEL =====

/// Heat at which each star is reached, from one to five
#define OUTPOST_POLICE_STAR_HEAT list(10, 25, 50, 90, 140)
/// Heat never goes above this
#define OUTPOST_POLICE_HEAT_CAP 180

// ===== CRIMES =====
// Keys of GLOB.outpost_crimes (police_core.dm): crime -> list(points, ceiling, floor), ceiling and floor in stars.
// None of these strings is the name of a report_crime() or register_aggression() argument (traps: dm-language.md).

#define OUTPOST_CRIME_ASSAULT_UNARMED "unarmed"
#define OUTPOST_CRIME_ASSAULT_ARMED "armed"
#define OUTPOST_CRIME_ASSAULT_SHOT "shot"
#define OUTPOST_CRIME_MURDER "murder"
#define OUTPOST_CRIME_VANDALISM "vandalism"
#define OUTPOST_CRIME_ASSAULT_STAFF "staff"
#define OUTPOST_CRIME_ASSAULT_CIVILIAN "civilian"
#define OUTPOST_CRIME_KILL_CIVILIAN "civilian_kill"
#define OUTPOST_CRIME_WEAPON_DRAWN "weapon_drawn"
#define OUTPOST_CRIME_GUNFIRE "gunfire"
#define OUTPOST_CRIME_CHECKPOINT_BREACH "breach"
#define OUTPOST_CRIME_TRESPASS "trespass"
#define OUTPOST_CRIME_RESIST "resist"
#define OUTPOST_CRIME_ASSAULT_OFFICER "officer"
#define OUTPOST_CRIME_KILL_OFFICER "officer_kill"
#define OUTPOST_CRIME_SLIP_CUFFS "slip_cuffs"
#define OUTPOST_CRIME_ABET "abet"
#define OUTPOST_CRIME_JAILBREAK "jailbreak"
#define OUTPOST_CRIME_ACCOMPLICE "accomplice"
#define OUTPOST_CRIME_LOCKER_THEFT "locker_theft"
// Wave 2 (spec-rehydrate.md; added by R0)
/// A trader or checkpoint guard dies within OUTPOST_POLICE_KILL_WINDOW of the offender's counted hit (1.4)
#define OUTPOST_CRIME_KILL_STAFF "staff_kill"
/// A checkpoint scanner emagged in sight of its guard or another witness (9)
#define OUTPOST_CRIME_GATE_TAMPER "gate_tamper"
/// A trader held up at its counter (10)
#define OUTPOST_CRIME_ARMED_ROBBERY "armed_robbery"
// OUTPOST JOBS seam (voidcrew/modules/outpost_jobs)
/// A fixer job's target (a structure the job placed) wrecked or tampered with, seen
#define OUTPOST_CRIME_SABOTAGE "sabotage"

// ===== WITNESSES (police_perception.dm) =====

/// What /datum/outpost_police_perception/proc/witness_of() returns
#define POLICE_WITNESS_NONE 0
#define POLICE_WITNESS_SAW 1
#define POLICE_WITNESS_HEARD 2
#define POLICE_WITNESS_CAMERA 3

/// How far a player witness sees a crime (and how far apart two tiles may be to be in sight of each other)
#define OUTPOST_POLICE_WITNESS_RANGE 9
/// How far a trader, checkpoint guard, townsperson or camera sees a crime (an officer sees by stealth's rules)
#define OUTPOST_POLICE_NPC_WITNESS_RANGE 8
/// A report waiting on a witness who can't make it now (out cold, held) is kept this long in case they come round
#define OUTPOST_POLICE_PENDING_KEEP (2 MINUTES)
/// A townsperson who saw a crime takes this long to tell anyone
#define OUTPOST_POLICE_CIVILIAN_REPORT_TIME (3 SECONDS)
/// An officer without a working radio reports in person: within this many tiles of an officer with one, or of the desk...
#define OUTPOST_POLICE_RADIOLESS_RANGE 7
/// ...for this long
#define OUTPOST_POLICE_RADIOLESS_TIME (3 SECONDS)
/// An officer whose search for a wanted person ran out is sent to look again no sooner than this
#define OUTPOST_POLICE_RESEARCH_GAP (20 SECONDS)
/// What an officer does at a patrol stop happens within this many tiles of it (a seat, the coffee machine, a chat)
#define OUTPOST_POLICE_STOP_REACH 3
/// A death this soon after the offender's last counted hit on the victim is a killing
#define OUTPOST_POLICE_KILL_WINDOW (30 SECONDS)

// ===== FORCE =====

/// What /datum/outpost_police/proc/force_level() returns, and an officer's `force`
#define POLICE_FORCE_NONE 0
#define POLICE_FORCE_ARREST 1
#define POLICE_FORCE_STUN 2
#define POLICE_FORCE_LETHAL 3

/// An officer's part in a squad at three stars and up (owner decision 37): takes the suspect alive, or shoots to kill
#define POLICE_ROLE_STUN "stun"
#define POLICE_ROLE_LETHAL "lethal"
/// One in this many responders carries stun gear, at three, four and five stars (at least one in a squad of two or more)
#define OUTPOST_POLICE_STUN_SHARE list(2, 3, 4)

// ===== UNITS AND SECTORS =====

#define POLICE_UNIT_BEAT "beat"
#define POLICE_UNIT_SERGEANT "sergeant"
#define POLICE_UNIT_OFFICER "officer"
#define POLICE_UNIT_TACTICAL "tactical"
#define POLICE_UNIT_MARSHAL "marshal"

/// Where an officer or suspect is (sector_of()). A hangar's sector is its /datum/outpost_berth itself.
#define POLICE_SECTOR_CONCOURSE "concourse"
#define POLICE_SECTOR_LOBBY "lobby"
#define POLICE_SECTOR_OUTSIDE "outside"

// ===== FADING AND RECORD =====

/// Hidden from every officer this long at one star before heat starts to drain
#define OUTPOST_POLICE_HIDE_1 (30 SECONDS)
/// The same at two stars
#define OUTPOST_POLICE_HIDE_2 (45 SECONDS)
/// Away from the outpost this long before heat starts to drain
#define OUTPOST_POLICE_AWAY_GRACE (10 SECONDS)
/// Heat lost per second while fading
#define OUTPOST_POLICE_FADE_PER_SECOND 1
/// A faded warrant leaves a prior this long
#define OUTPOST_POLICE_PRIOR_TIME (20 MINUTES)
/// A faded warrant of three stars or more bars its holder this long
#define OUTPOST_POLICE_BAR_TIME (15 MINUTES)

// ===== RESPONSE =====

/// Officers on the scene per star level
#define OUTPOST_POLICE_UNITS list(2, 3, 4, 7, 10)
/// Officers per wave per star level
#define OUTPOST_POLICE_WAVE list(1, 1, 2, 3, 4)
/// Time between waves per star level
#define OUTPOST_POLICE_CADENCE list(15 SECONDS, 15 SECONDS, 20 SECONDS, 15 SECONDS, 12 SECONDS)
/// Most living officers at one outpost
#define OUTPOST_POLICE_CAP_OUTPOST 12
/// Most living officers in the world
#define OUTPOST_POLICE_CAP_WORLD 24
/// Most officer bodies lying about at one outpost
#define OUTPOST_POLICE_CORPSE_CAP 8
/// An officer's body lies this long
#define OUTPOST_POLICE_CORPSE_LIFETIME (3 MINUTES)

// ===== ARREST, FINES, CELLS =====

/// Fine at one and two stars, before the zone multiplier
#define OUTPOST_POLICE_FINES list(300, 800)
/// Time in a cell after a paid fine, at one and two stars
#define OUTPOST_POLICE_HOLDS list(30 SECONDS, 60 SECONDS)
/// Jail term when the fine is not paid, at one and two stars (no debt afterwards); at three to five stars, the
/// sentence with no fine on offer (owner decision 37)
#define OUTPOST_POLICE_JAIL list(3 MINUTES, 6 MINUTES, 10 MINUTES, 15 MINUTES, 20 MINUTES)
/// A jailed prisoner's fine is tried again this often
#define OUTPOST_POLICE_BAIL_RETRY (30 SECONDS)
/// Searching one item off a suspect
#define OUTPOST_POLICE_SEARCH_ITEM (3 SECONDS)
/// A whole search takes no longer than this
#define OUTPOST_POLICE_SEARCH_MAX (9 SECONDS)
/// Stripping a prisoner's gear into a locker
#define OUTPOST_POLICE_STRIP_TIME (8 SECONDS)
/// Crime tools a warrant remembers
#define OUTPOST_POLICE_EVIDENCE_MAX 8
/// Property lockers per station
#define OUTPOST_POLICE_LOCKERS 4
/// A cell door held open for a prisoner in crit or dead, at most
#define OUTPOST_POLICE_CELL_MEDIC_OPEN (2 MINUTES)
/// A cell door stays open this long on release or when forced
#define OUTPOST_POLICE_CELL_OPEN (10 SECONDS)
/// Forcing a cell door takes this long
#define OUTPOST_POLICE_CELL_FORCE_TIME (12 SECONDS)
/// A prisoner carried out of a cell has this long to walk back in
#define OUTPOST_POLICE_CELL_RETURN (20 SECONDS)

// ===== FOUR AND FIVE STARS =====

/// Embargo length at four and five stars, at the outpost where it happened
#define OUTPOST_POLICE_EMBARGO list(15 MINUTES, 30 MINUTES)
/// Added to the embargo per officer killed
#define OUTPOST_POLICE_EMBARGO_PER_KILL (5 MINUTES)
/// The embargo never runs longer than this
#define OUTPOST_POLICE_EMBARGO_MAX (120 MINUTES)

// ===== LIFTS AND AI =====

/// A lift point whose unit has had no path this long is skipped
#define OUTPOST_POLICE_LIFT_BLOCKED (10 SECONDS)
/// ...for this long
#define OUTPOST_POLICE_LIFT_SKIP (2 MINUTES)
/// A unit built out of sight is at least this far from every player
#define OUTPOST_POLICE_UNSEEN_SPAWN_DIST 12
/// A case step stuck this long goes back to the start
#define OUTPOST_POLICE_STEP_TIMEOUT (60 SECONDS)
/// An officer stands by a suspect in crit this long
#define OUTPOST_POLICE_CRIT_WAIT (45 SECONDS)
/// Standing in an officer's line of fire or pulling an officer this long is resisting
#define OUTPOST_POLICE_BLOCK_TIME (5 SECONDS)
/// The police tick stops after this long with nothing to do (no warrant, no response unit, no prisoner)
#define OUTPOST_POLICE_IDLE_STOP (30 SECONDS)

// ===== WHAT OFFICERS SAY (JSON contexts in AMBIENT_STRINGS_POLICE) =====

#define POLICE_LINE_WARN "warn"
#define POLICE_LINE_ORDER "order"
#define POLICE_LINE_CHASE "chase"
#define POLICE_LINE_STUN "stun"
#define POLICE_LINE_SHOTS "shots"
#define POLICE_LINE_ALL_UNITS "all_units"
#define POLICE_LINE_MARSHAL "marshal"
#define POLICE_LINE_LOST "lost"
#define POLICE_LINE_CUFF "cuff"
#define POLICE_LINE_WALK "walk"
#define POLICE_LINE_MAKE_WAY "make_way"
#define POLICE_LINE_BOOK "book"
#define POLICE_LINE_RELEASE "release"
#define POLICE_LINE_MEDIC "medic"
#define POLICE_LINE_OFFICER_DOWN "officer_down"
#define POLICE_LINE_CLEAR "clear"
#define POLICE_LINE_KNOCK "knock"
#define POLICE_LINE_CELL_ALARM "cell_alarm"
#define POLICE_LINE_MOVE_ALONG "move_along"
#define POLICE_LINE_RADIO_CALL "radio_call"
#define POLICE_LINE_RADIO_ACK "radio_ack"
#define POLICE_LINE_SEARCH "search"
#define POLICE_LINE_EVIDENCE "evidence"
#define POLICE_LINE_STRIP "strip"
#define POLICE_LINE_BAIL "bail"
#define POLICE_LINE_LOCKER_THIEF "locker_thief"

/// The officers' dialogue file in AMBIENT_STRINGS_DIR
#define AMBIENT_STRINGS_POLICE "outpost_police.json"

/// Access on officers' IDs: police doors open for it
#define ACCESS_OUTPOST_POLICE "outpost_police"

// ===== SIGNALS (all sent on the /datum/outpost_police) =====

/// A warrant's stars changed: (datum/mind/mind, old_stars, new_stars)
#define COMSIG_OUTPOST_POLICE_STARS "outpost_police_stars"
/// An officer went down: (mob/living/officer, mob/living/killer or null)
#define COMSIG_OUTPOST_POLICE_OFFICER_DOWN "outpost_police_officer_down"
/// A suspect was booked into a cell: (mob/living/suspect, jailed TRUE/FALSE)
#define COMSIG_OUTPOST_POLICE_BOOKED "outpost_police_booked"
/// A prisoner was let out: (mob/living/suspect)
#define COMSIG_OUTPOST_POLICE_RELEASED "outpost_police_released"
// OUTPOST JOBS seam (voidcrew/modules/outpost_jobs)
/// Every counted crime, star or no star (count_crime()): (datum/mind/mind, crime, atom/victim, stars_after, derived)
#define COMSIG_OUTPOST_POLICE_CRIME "outpost_police_crime"
/// A cell door was forced open (force_door()): (datum/outpost_police_cell/cell, mob/living/user)
#define COMSIG_OUTPOST_POLICE_CELL_FORCED "outpost_police_cell_forced"
