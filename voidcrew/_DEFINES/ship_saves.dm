/// Bump this when the payload layout or the list of saved vars changes. Older saves are then refused.
#define SHIP_SAVE_FORMAT 1
/// How many ships one player can have saved at once.
#define SHIP_SAVE_SLOTS 3
/// The least a save can cost, in ship parts of every class together.
#define SHIP_SAVE_PRICE_MIN 5
/// A hull costs one misc part per this much mass, rounded up.
#define SHIP_SAVE_MASS_PER_PART 150
/// How long a hull's survey is good for while a window is open on it.
#define SHIP_SAVE_SURVEY_LIFE (10 SECONDS)
/// A hull plan longer than this isn't sent to the screen or kept.
#define SHIP_SAVE_PLAN_MAX_LENGTH 8000
/// What setting a new ship join password costs, in ship parts.
#define SHIP_PASSWORD_PRICE 3
