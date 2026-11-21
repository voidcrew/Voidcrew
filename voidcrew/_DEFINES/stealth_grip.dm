// The grip from behind and hands up (voidcrew/modules/stealth/stealth_grip.dm, stealth_holdup.dm).

/// Trait source for the mute a hand over the mouth puts on its victim.
#define STEALTH_GRIP_TRAIT "stealth_grip"

/// Oxygen damage per second the squeeze's arm adds on a bare neck, on top of tg's own strangle (about 1.5 a second).
/// Together: out (tg's 50) in about 9 s.
#define STEALTH_SQUEEZE_OXY_RATE 4
/// The squeeze lets go once he is out and this deep (tg's breathing takes it off again; he stays out about 10 s more).
#define STEALTH_SQUEEZE_RELEASE_OXY 75
/// A hurt guard is let go sooner, this far above tg's full crit (HEALTH_THRESHOLD_FULLCRIT), where tg's crit breathing
/// would go on choking him. A healthy guard never gets this low before STEALTH_SQUEEZE_RELEASE_OXY.
#define STEALTH_SQUEEZE_CRIT_MARGIN 10
/// Neck cover (hv_crit_cover_rating(), melee, worn and physiology armour stacked) at which the squeeze can't close.
#define STEALTH_SQUEEZE_MAX_COVER 60

/// How long a guard who put his hands up waits, once nobody covers him any more, before he makes his move.
#define STEALTH_HOLDUP_BEAT (2 SECONDS)
/// tg's *surrender: a 20 second Paralyze (code/modules/mob/living/emote.dm).
#define STEALTH_HOLDUP_SURRENDER_TIME (20 SECONDS)
/// A guard with an alert friend this close, in view, doesn't put his hands up.
#define STEALTH_HOLDUP_BACKUP_RANGE 7
