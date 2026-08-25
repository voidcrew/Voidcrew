// ===== GRAND COLOSSEUM (voidcrew/modules/colosseum/) =====

// Match state machine states (see colosseum_controller.dm for the loop)
#define COLOSSEUM_STATE_IDLE "idle"
#define COLOSSEUM_STATE_SIGNUP "signup"
#define COLOSSEUM_STATE_SEATING "seating"
#define COLOSSEUM_STATE_LIVE "live"
#define COLOSSEUM_STATE_RESOLVED "resolved"
#define COLOSSEUM_STATE_RESET "reset"

// Phase timings
/// How long registration stays open once someone opens it. Generous: crews fly in from across the sector.
#define COLOSSEUM_SIGNUP_DURATION (6 MINUTES)
/// How long contestants have to physically reach staging after the roster locks.
#define COLOSSEUM_SEATING_DURATION (2 MINUTES)
/// Dramatic pause between sealing staging and popping the arena gates.
#define COLOSSEUM_GATE_COUNTDOWN (10 SECONDS)
/// Spoils vault winners-only claim window after a match resolves.
#define COLOSSEUM_CLAIM_WINDOW (5 MINUTES)
/// How long a disconnected contestant has to reconnect before forfeiting.
#define COLOSSEUM_DISCONNECT_GRACE (45 SECONDS)
/// Console cooldown between one match ending (or fizzling) and the next signup.
#define COLOSSEUM_SIGNUP_COOLDOWN (90 SECONDS)
/// Fallback match time limit for modes that don't set their own.
#define COLOSSEUM_DEFAULT_TIME_LIMIT (10 MINUTES)
/// Pause between tournament rounds (sweep + reset + reseat).
#define COLOSSEUM_TOURNAMENT_INTERMISSION (45 SECONDS)

// Gate poddoor ids, must match the ids mapped in grand_colosseum_main.dmm
#define COLOSSEUM_GATE_RED "colo_gate_red"
#define COLOSSEUM_GATE_BLUE "colo_gate_blue"
#define COLOSSEUM_GATE_SOLO "colo_gate_solo"
#define COLOSSEUM_SEAL "colo_seal"

// Team ids used by rosters and modes
#define COLOSSEUM_TEAM_SOLO "solo"
#define COLOSSEUM_TEAM_RED "red"
#define COLOSSEUM_TEAM_BLUE "blue"

// Contestant elimination reasons (announcement flavor + logs)
#define COLOSSEUM_ELIM_DEATH "slain"
#define COLOSSEUM_ELIM_DELETED "lost"
#define COLOSSEUM_ELIM_DISCONNECT "abandoned the match"
#define COLOSSEUM_ELIM_FLED "fled the arena"
#define COLOSSEUM_ELIM_CUT "cut from the bracket"

/// The dynamic event may never surface the venue before this much round time.
#define COLOSSEUM_EARLIEST_SPAWN (40 MINUTES)

/// Trait source for contestant area-sensitivity (arena-departure detection).
#define COLOSSEUM_TRAIT "colosseum"

// Arena event scheduler (colosseum_arena_events.dm)
/// Delay between an arena hazard being telegraphed and it going live.
#define COLOSSEUM_EVENT_TELEGRAPH (4 SECONDS)
/// How long hazard turf swaps last before the sand is restored.
#define COLOSSEUM_HAZARD_DURATION (12 SECONDS)

/// Camera network shared by the arena cameras and the observation consoles.
/// Safe as a static string: the venue is one-per-round by construction.
#define COLOSSEUM_CAMERA_NETWORK "colosseum"
