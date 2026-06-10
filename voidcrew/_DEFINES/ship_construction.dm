// Ship construction console defines
// Kept in _DEFINES (not the construction module) so they compile before the
// files that use them -- DreamMaker re-sorts .dme includes alphabetically,
// so module files can't rely on include order for defines.

// Upgrade flags for ship construction console
#define SHIP_CONSTRUCTION_UPGRADE_RTD (1 << 0)
#define SHIP_CONSTRUCTION_UPGRADE_RPD (1 << 1)
#define SHIP_CONSTRUCTION_UPGRADE_RLD (1 << 2)
#define SHIP_CONSTRUCTION_UPGRADE_TRAY (1 << 3)

// T-ray scanner modes for ship construction console
#define SHIP_TRAY_MODE_OFF "off"
#define SHIP_TRAY_MODE_TRAY "t-ray"
#define SHIP_TRAY_MODE_PIPE "pipe"
#define SHIP_TRAY_MODE_THERMAL "thermal"
