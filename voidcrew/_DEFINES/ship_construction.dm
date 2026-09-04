// Ship construction console defines
// Kept in _DEFINES (not the construction module) so they compile before the
// files that use them -- DreamMaker re-sorts .dme includes alphabetically,
// so module files can't rely on include order for defines.

// Upgrade flags for ship construction console
#define SHIP_CONSTRUCTION_UPGRADE_RTD (1 << 0)
#define SHIP_CONSTRUCTION_UPGRADE_RPD (1 << 1)
#define SHIP_CONSTRUCTION_UPGRADE_RLD (1 << 2)
#define SHIP_CONSTRUCTION_UPGRADE_TRAY (1 << 3)
#define SHIP_CONSTRUCTION_UPGRADE_SERVO (1 << 4)
#define SHIP_CONSTRUCTION_UPGRADE_SERVO_MK2 (1 << 5)

// Build time multipliers the fabrication servo upgrades apply to every delay the
// construction drone incurs. Tier 1 shaves a quarter off, tier 2 halves it.
#define SHIP_CONSTRUCTION_SERVO_SPEED_MOD 0.75
#define SHIP_CONSTRUCTION_SERVO_MK2_SPEED_MOD 0.5

// T-ray scanner modes for ship construction console
#define SHIP_TRAY_MODE_OFF "off"
#define SHIP_TRAY_MODE_TRAY "t-ray"
#define SHIP_TRAY_MODE_PIPE "pipe"
#define SHIP_TRAY_MODE_THERMAL "thermal"

// Silo material costs for a console-built camera (mirrors /obj/item/wallframe/camera custom_materials)
#define SHIP_CAMERA_IRON_COST (SMALL_MATERIAL_AMOUNT * 4)
#define SHIP_CAMERA_GLASS_COST (SMALL_MATERIAL_AMOUNT * 2.5)
// Delay to mount a camera with the console drone
#define SHIP_CAMERA_BUILD_DELAY (2 SECONDS)
// Delay to remove a camera with the console drone
#define SHIP_CAMERA_DECONSTRUCT_DELAY (2 SECONDS)

// Base times the console drone spends raising a wall / laying a floor, before the
// fabrication servo speed upgrades are applied
#define SHIP_RCD_WALL_BUILD_DELAY (2 SECONDS)
#define SHIP_RCD_FLOOR_BUILD_DELAY (1 SECONDS)
