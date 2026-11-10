// Stealth layer for chosen human NPCs (voidcrew/modules/stealth/). Awareness is AI state only.

// ===== Awareness states (BB_STEALTH_STATE) =====
#define STEALTH_UNAWARE "unaware"
#define STEALTH_SUSPICIOUS "suspicious"
#define STEALTH_ALERT "alert"
#define STEALTH_SEARCHING "searching"

// ===== Blackboard keys =====
/// One of the STEALTH_* states
#define BB_STEALTH_STATE "stealth_state"
/// world.time of the last state change
#define BB_STEALTH_STATE_SINCE "stealth_state_since"
/// world.time the guard last stopped being unaware (stealth_was_unaware())
#define BB_STEALTH_UNAWARE_LOST_AT "stealth_unaware_lost_at"
/// TRUE once alerted, searching or hit. Fades after STEALTH_WARY_TIME with nothing new (checked each scan).
#define BB_STEALTH_WARY "stealth_wary"
/// The candidate with the highest notice
#define BB_STEALTH_FOCUS "stealth_focus"
/// Where it last saw (or was hit from) whoever it is after
#define BB_STEALTH_LAST_SEEN_TURF "stealth_last_seen_turf"
/// world.time of that sighting
#define BB_STEALTH_LAST_SEEN_AT "stealth_last_seen_at"
/// REFs of fallen group members it has already reacted to
#define BB_STEALTH_BODIES_SEEN "stealth_bodies_seen"
/// Its claimed stop, or the sentry's post
#define BB_STEALTH_HOME_TURF "stealth_home_turf"

// Notice entry fields (the controller's notice_map)
#define STEALTH_ENTRY_NOTICE 1
#define STEALTH_ENTRY_TURF 2
#define STEALTH_ENTRY_SEEN_AT 3

// ===== Bark kinds =====
#define STEALTH_BARK_SUSPICIOUS "stealth_suspicious"
#define STEALTH_BARK_GIVE_UP "stealth_give_up"
#define STEALTH_BARK_LOST "stealth_lost"
#define STEALTH_BARK_SEARCH "stealth_search"
#define STEALTH_BARK_HIT_UNSEEN "stealth_hit_unseen"
#define STEALTH_BARK_BODY "stealth_body"
#define STEALTH_BARK_CHATTER "stealth_chatter"
/// It just put its target down
#define STEALTH_BARK_DOWNED "stealth_target_downed"

// ===== What a stealth goto is for =====
#define STEALTH_GOTO_PATROL "patrol"
#define STEALTH_GOTO_INVESTIGATE "investigate"
#define STEALTH_GOTO_BODY "body"
#define STEALTH_GOTO_SEARCH "search"
#define STEALTH_GOTO_HOME "home"

// ===== Numbers (first playtest defaults; the owner tunes them) =====
#define STEALTH_SCAN_INTERVAL (1 SECONDS)
#define STEALTH_SIGHT_RANGE 8
#define STEALTH_ALERT_MAX_RANGE 7
#define STEALTH_DARK_SIGHT_RANGE 4
#define STEALTH_DARK_LUMCOUNT 0.2
#define STEALTH_DARK_MULT 0.5
#define STEALTH_CLOSE_RANGE 2
#define STEALTH_CONE_HALF_ANGLE 60
#define STEALTH_WARY_HALF_ANGLE 75
#define STEALTH_SEARCH_HALF_ANGLE 90
#define STEALTH_NOTICE_RATE 1.0
#define STEALTH_NOTICE_MIN_FALLOFF 0.25
#define STEALTH_SUSPICIOUS_AT 1.0
#define STEALTH_ALERT_AT 2.5
#define STEALTH_NOTICE_DECAY 0.34
#define STEALTH_NOTICE_FORGET (20 SECONDS)
#define STEALTH_BEHIND_RATE 0.4
#define STEALTH_RUN_MULT 2
#define STEALTH_STILL_MULT 0.5
#define STEALTH_LYING_MULT 0.5
#define STEALTH_SUSPICIOUS_MULT 1.5
#define STEALTH_SEARCHING_MULT 2
#define STEALTH_WARY_MULT 1.5
#define STEALTH_MAX_CANDIDATES 8
#define STEALTH_INVESTIGATE_DELAY (2 SECONDS)
#define STEALTH_LOOK_AROUND_TIME (4 SECONDS)
#define STEALTH_SUSPICIOUS_TIMEOUT (12 SECONDS)
#define STEALTH_LOSE_TARGET_TIME (4 SECONDS)
#define STEALTH_SEARCH_TIME (40 SECONDS)
/// After putting its target down with nobody else about: how long it looks round before calming down
#define STEALTH_CALM_LOOK_TIME (6 SECONDS)
/// How long wary lasts after the last notice gain, hit, touch, alert or search
#define STEALTH_WARY_TIME (60 SECONDS)
#define STEALTH_SEARCH_POINTS 3
#define STEALTH_SEARCH_RADIUS 5
#define STEALTH_BODY_SCAN_INTERVAL (2 SECONDS)
#define STEALTH_BARK_KIND_COOLDOWN (8 SECONDS)
#define STEALTH_GROUP_RADIUS 48
#define STEALTH_ROUTE_CLAIM_RANGE 2
#define STEALTH_PATROL_DEFAULT_WAIT (6 SECONDS)
#define STEALTH_LOOK_TURN_INTERVAL (3 SECONDS)
#define STEALTH_LOOK_TURN_CHANCE 50
#define STEALTH_LOOK_TURN_ARC 90
#define STEALTH_SENTRY_TURN_INTERVAL (8 SECONDS)
#define STEALTH_CHATTER_RANGE 3
#define STEALTH_CHATTER_COOLDOWN (45 SECONDS)
#define STEALTH_PATROL_MAX_FAILS 3
#define STEALTH_PATROL_SKIP_TIME (2 MINUTES)
#define STEALTH_PATROL_MAX_PATH 60
#define STEALTH_LEASH_RANGE 24
#define STEALTH_ADMIN_OVERLAY_TIME (5 MINUTES)
/// Seconds of search between "Come on out." lines
#define STEALTH_SEARCH_BARK_INTERVAL (12 SECONDS)

// The mark over a guard's head (stealth_meter.dm, owner decision 27)
/// Pixel rows in the "?" and "!" glyphs: fill and drain steps
#define STEALTH_METER_ROWS 7
/// Tiles from the guard within which a living player makes the mark worth drawing
#define STEALTH_METER_RANGE 10
/// pixel_z of the glyph's bottom over a standing, medium-height guard: a clear gap over the hair
#define STEALTH_METER_HEAD_Z 36
/// pixel_z of the glyph's bottom over a guard lying down (its sprite also drops PIXEL_Y_OFFSET_LYING)
#define STEALTH_METER_LYING_Z 29

/// The scav den's side
#define FACTION_SCAV "scav"
