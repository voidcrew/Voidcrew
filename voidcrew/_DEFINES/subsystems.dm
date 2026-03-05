// See code/__DEFINES/subsystems.dm for other init orders
#define INIT_ORDER_OVERMAP -15
#define INIT_ORDER_PLANET_MOBS (INIT_ORDER_OVERMAP + 4)
#define FIRE_PRIORITY_PLANET_MOBS 5

///Signal sent when a ship leaves a z level: (obj/docking_port/mobile/voidcrew/source, z_level)
#define COMSIG_GLOB_Z_SHIP_PROBE "!z-probe"
