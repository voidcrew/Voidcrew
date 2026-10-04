// Outpost owner shop (outpost_shop.dm, outpost_shop_stock.dm)

#define OUTPOST_SHOP_COST 2000
/// Registry cut on shop sales, in percent
#define OUTPOST_SHOP_SALE_FEE_PCT 0
/// Stock limits: items held, listings, categories and category name length
#define OUTPOST_SHOP_MAX_ITEMS 500
#define OUTPOST_SHOP_MAX_LISTINGS 150
#define OUTPOST_SHOP_MAX_CATEGORIES 16
#define OUTPOST_SHOP_CATEGORY_NAME_LEN 24
/// Highest price per unit, and highest total of one purchase
#define OUTPOST_SHOP_MAX_PRICE 1000000
#define OUTPOST_SHOP_MAX_TOTAL 1000000
/// Items one purchase may take
#define OUTPOST_SHOP_MAX_BUY 10
/// Items one eject may move
#define OUTPOST_SHOP_EJECT_LIMIT 100
/// Sales kept in the shop's own log
#define OUTPOST_SHOP_SALES_LOG 20
/// Purchases above this total ask for a second confirmation
#define OUTPOST_SHOP_CONFIRM_TOTAL 5000
/// Stock UI updates are batched this long
#define OUTPOST_SHOP_UI_FLUSH (0.5 SECONDS)
#define OUTPOST_SHOP_INSPECT_COOLDOWN (1 SECONDS)

