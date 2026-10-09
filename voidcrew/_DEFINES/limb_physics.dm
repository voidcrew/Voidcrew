// Box2D physics for the limb rig (voidcrew/modules/limb_rig/physics/).

/// Pixels to a metre. A human-sized body comes out about 1.8 metres tall.
#define LIMB_PHYSICS_PPM 20
/// Every physics step is exactly this long, in seconds, whatever the server's doing: the
/// simulation only depends on how many steps it's taken, never on how long they took.
#define LIMB_PHYSICS_DT (1 / 60)
/// Steps taken each time the subsystem fires (every decisecond): a tenth of a second's worth.
#define LIMB_PHYSICS_STEPS_PER_FIRE 6
/// How long a body's steps may take each fire, in milliseconds, on average. Past that it takes
/// fewer steps a fire (down to one), and runs slow rather than the server does.
#define LIMB_PHYSICS_STEP_BUDGET 5
#define LIMB_PHYSICS_VELOCITY_ITERATIONS 8
#define LIMB_PHYSICS_POSITION_ITERATIONS 3
/// Earth's.
#define LIMB_PHYSICS_GRAVITY -9.8
/// The collision group a ragdoll's pieces share. Negative, so they never collide with each other,
/// only with the floor and walls.
#define LIMB_PHYSICS_RAGDOLL_GROUP -1
/// Box2D body types.
#define LIMB_PHYSICS_STATIC 0
#define LIMB_PHYSICS_DYNAMIC 2
/// How high a human's hand is, where held items are drawn from (as the sprite rig has it).
#define LIMB_PHYSICS_HUMAN_HAND_Y 12.5
/// The trait source Serverblight holds its victim still with.
#define SERVERBLIGHT_TRAIT "serverblight"
/// How many metres of the ragdoll's frame a tile is.
#define SERVERBLIGHT_TILE_METRES (32 / LIMB_PHYSICS_PPM)
/// How fast Serverblight hunts, in tiles a second.
#define SERVERBLIGHT_SPEED 5.5
/// How far it can see someone to hunt them, in tiles.
#define SERVERBLIGHT_SIGHT 8
/// Someone in reach of Serverblight's hands, to them: a box this big, in metres, feet at the bottom.
#define SERVERBLIGHT_PREY_HALF_WIDTH 0.45
#define SERVERBLIGHT_PREY_HALF_HEIGHT 0.9
/// How much holding it takes to take someone: a point for every hand on them, every fire (with
/// five hands, six fires of all of them). Nothing holding them, it slips back two a fire.
#define SERVERBLIGHT_ASSIMILATION 30
/// How many people taken in are grown onto the body. Past that they're only taken.
#define SERVERBLIGHT_MAX_DRAWN_MERGES 3
/// How much slower someone moves for each of Serverblight's hands on them, in deciseconds a tile.
#define SERVERBLIGHT_GRIP_SLOWDOWN 0.8
/// The most Serverblight's hands slow anyone down, however many there are: slow, never stuck.
#define SERVERBLIGHT_GRIP_MAX_SLOWDOWN 6
/// How many of the pieces nearest it each piece of someone taken in is glued to.
#define SERVERBLIGHT_GLUE_PER_PIECE 3
/// How fast glued pieces lying in each other are pushed apart, at most, in metres a second a fire...
#define SERVERBLIGHT_PUSHBACK 1
/// ...and how close, in metres, they have to be for it.
#define SERVERBLIGHT_PUSHBACK_REACH 0.9
/// The fastest any piece of a Serverblighted body is let go, in metres a second...
#define SERVERBLIGHT_TOP_SPEED 10
/// ...and spun, in radians a second. Unchecked, its pieces spin at Box2D's own limit (thirty pi)
/// and the body comes apart.
#define SERVERBLIGHT_TOP_SPIN 15
/// How far from its torso, in metres, any piece of a Serverblighted body is ever meant to get. Past
/// that it's coming apart, and it starts over (no more than every SERVERBLIGHT_REBUILD_COOLDOWN).
#define SERVERBLIGHT_TORN_REACH 5
#define SERVERBLIGHT_REBUILD_COOLDOWN (3 SECONDS)
/// How long a killed Serverblight lies dead before it gets back up.
#define SERVERBLIGHT_DEATH_TIME (1 MINUTES)
/// With no gravity, how many fires between Serverblight throwing itself off things.
#define SERVERBLIGHT_PUSHOFF_FIRES 5
/// How much health each body Serverblight takes in adds to it.
#define SERVERBLIGHT_HEALTH_PER_BODY 100
