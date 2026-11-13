// Stealth step 3b: the garrotte and the chokehold (voidcrew/modules/stealth/stealth_takedown.dm).

/// Trait source for what a takedown hold puts on its victim (the mute while the airway is shut).
#define STEALTH_TAKEDOWN_TRAIT "stealth_takedown"
/// do_after interaction key for the wind-up.
#define STEALTH_TAKEDOWN_DOAFTER "stealth_takedown"

/// The wind-up before the hold closes: the wire goes over the head, or the arm round the neck. Turning round ends it.
#define STEALTH_TAKEDOWN_WINDUP (0.8 SECONDS)

/// Takedown kinds.
#define STEALTH_TAKEDOWN_CHOKE "choke"
#define STEALTH_TAKEDOWN_GARROTTE "garrotte"

/// Oxygen damage per second the chokehold's arm adds on a bare neck, on top of tg's own strangle (one missed breath
/// per Life tick, about 1.5 a second). Together: out (tg's 50) in about 9 s.
#define STEALTH_CHOKE_OXY_RATE 4
/// The garrotte's wire per second on a bare neck. Together with tg's strangle: out in about 5 s, dead (oxygen 200) in
/// about 20 s if it is never let go.
#define STEALTH_GARROTTE_OXY_RATE 8
/// The chokehold lets go once the victim is out and this deep (tg's breathing takes 2.5 a second off again, so he
/// stays out about 10 s after the release).
#define STEALTH_CHOKE_RELEASE_OXY 75

/// Neck cover (hv_crit_cover_rating(), melee, worn and physiology armour stacked) at which neither hold can close.
#define STEALTH_TAKEDOWN_MAX_COVER 60
