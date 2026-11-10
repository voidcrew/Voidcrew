// Tutorial checklist keys (voidcrew/modules/tutorials).
// Stored in the tg `tutorial_completions` table. Every key starts with "vc/" so it can
// never collide with tg's own tutorial keys, and must stay at most 64 characters.
// Never rename a key that has shipped: players' saved progress is stored under it.

// Checklist items. An item key is written once every counted step of the item is done,
// so later step additions don't reopen a finished item.
#define TUTORIAL_ITEM_SHIP "vc/ship"
#define TUTORIAL_ITEM_CONTRACT "vc/contract"
#define TUTORIAL_ITEM_RESEARCH "vc/research"
#define TUTORIAL_ITEM_SURVEYS "vc/surveys"
#define TUTORIAL_ITEM_RUIN "vc/ruin"
#define TUTORIAL_ITEM_TRADE "vc/trade"
#define TUTORIAL_ITEM_POWER "vc/power"
#define TUTORIAL_ITEM_CHROME "vc/chrome"
#define TUTORIAL_ITEM_SURGERY "vc/surgery"
#define TUTORIAL_ITEM_ZONES "vc/zones"
#define TUTORIAL_ITEM_STORAGE "vc/storage"
#define TUTORIAL_ITEM_REPAIR_DRONES "vc/repair_drones"
#define TUTORIAL_ITEM_SHIP_SAVE "vc/ship_save"
#define TUTORIAL_ITEM_VESTIGE "vc/vestige"

// Your ship
#define TUTORIAL_STEP_SHIP_MANAGE "vc/ship/manage"
#define TUTORIAL_STEP_SHIP_SEARCH "vc/ship/search"
#define TUTORIAL_STEP_SHIP_COURSE "vc/ship/course"
#define TUTORIAL_STEP_SHIP_DOCK "vc/ship/dock"
#define TUTORIAL_STEP_SHIP_UNDOCK "vc/ship/undock"
#define TUTORIAL_STEP_SHIP_BUILD "vc/ship/build"

// First contract
#define TUTORIAL_STEP_CONTRACT_TAKE "vc/contract/take"
#define TUTORIAL_STEP_CONTRACT_WORK "vc/contract/work"
#define TUTORIAL_STEP_CONTRACT_TURN_IN "vc/contract/turn_in"

// R&D setup
#define TUTORIAL_STEP_RESEARCH_KIT "vc/research/kit"
#define TUTORIAL_STEP_RESEARCH_SERVER "vc/research/server"
#define TUTORIAL_STEP_RESEARCH_DISK "vc/research/disk"
#define TUTORIAL_STEP_RESEARCH_CONSOLE "vc/research/console"
#define TUTORIAL_STEP_RESEARCH_PROTOLATHE "vc/research/protolathe"
#define TUTORIAL_STEP_RESEARCH_MULTITOOL "vc/research/multitool"
#define TUTORIAL_STEP_RESEARCH_LINK "vc/research/link"

// Surveys
#define TUTORIAL_STEP_SURVEYS_NODE "vc/surveys/node"
#define TUTORIAL_STEP_SURVEYS_BUILD "vc/surveys/build"
#define TUTORIAL_STEP_SURVEYS_SURVEY "vc/surveys/survey"
#define TUTORIAL_STEP_SURVEYS_NOTES "vc/surveys/notes"

// Planet ruin
#define TUTORIAL_STEP_RUIN_LAND "vc/ruin/land"
#define TUTORIAL_STEP_RUIN_FIND "vc/ruin/find"
#define TUTORIAL_STEP_RUIN_CACHE "vc/ruin/cache"

// Outpost trade
#define TUTORIAL_STEP_TRADE_TRAVEL "vc/trade/travel"
#define TUTORIAL_STEP_TRADE_ELEVATOR "vc/trade/elevator"
#define TUTORIAL_STEP_TRADE_BUY "vc/trade/buy"
#define TUTORIAL_STEP_TRADE_SELL "vc/trade/sell"

// Ship power
#define TUTORIAL_STEP_POWER_SMES "vc/power/smes"
#define TUTORIAL_STEP_POWER_GENERATOR "vc/power/generator"
#define TUTORIAL_STEP_POWER_APC "vc/power/apc"

// Cyberware
#define TUTORIAL_STEP_CHROME_BUY "vc/chrome/buy"
#define TUTORIAL_STEP_CHROME_INSTALL "vc/chrome/install"
#define TUTORIAL_STEP_CHROME_EXECUTE "vc/chrome/execute"

// First surgery
#define TUTORIAL_STEP_SURGERY_START "vc/surgery/start"
#define TUTORIAL_STEP_SURGERY_FINISH "vc/surgery/finish"
#define TUTORIAL_STEP_SURGERY_DISSECT "vc/surgery/dissect"

// Zones
#define TUTORIAL_STEP_ZONES_YELLOW "vc/zones/yellow"
#define TUTORIAL_STEP_ZONES_WARFARE "vc/zones/warfare"
#define TUTORIAL_STEP_ZONES_RED "vc/zones/red"

// Storage
#define TUTORIAL_STEP_STORAGE_SHELF "vc/storage/shelf"
#define TUTORIAL_STEP_STORAGE_CRATE "vc/storage/crate"
#define TUTORIAL_STEP_STORAGE_LOCKER "vc/storage/locker"
#define TUTORIAL_STEP_STORAGE_STORE "vc/storage/store"

// Repair drones
#define TUTORIAL_STEP_REPAIR_DRONES_RESEARCH "vc/repair_drones/research"
#define TUTORIAL_STEP_REPAIR_DRONES_ASSEMBLE "vc/repair_drones/assemble"
#define TUTORIAL_STEP_REPAIR_DRONES_LINK "vc/repair_drones/link"
#define TUTORIAL_STEP_REPAIR_DRONES_REPAIR "vc/repair_drones/repair"

// Save your ship
#define TUTORIAL_STEP_SHIP_SAVE_DOCK "vc/ship_save/dock"
#define TUTORIAL_STEP_SHIP_SAVE_SAVE "vc/ship_save/save"
#define TUTORIAL_STEP_SHIP_SAVE_LOAD "vc/ship_save/load"

// Vestige pact
#define TUTORIAL_STEP_VESTIGE_FIND "vc/vestige/find"
#define TUTORIAL_STEP_VESTIGE_PACT "vc/vestige/pact"
#define TUTORIAL_STEP_VESTIGE_TRIAL "vc/vestige/trial"
#define TUTORIAL_STEP_VESTIGE_CLAIM "vc/vestige/claim"

/// Prefix shared by every Voidcrew tutorial key in `tutorial_completions`.
#define TUTORIAL_KEY_PREFIX "vc/"
