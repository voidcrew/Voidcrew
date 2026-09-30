// Voidcrew extensions to code/modules/cargo/materials_market.dm.

/// The order list this market files into. Null means it has nowhere to file an order.
/// `announce_refusal` is TRUE only on the path that is actually placing one, so the override
/// can say why it is refusing without spamming that message from every ui_data() tick.
/obj/machinery/materials_market/proc/get_order_list(announce_refusal = FALSE)
	return SSshuttle.shopping_list

/// Whether `id_card` may spend a budget here instead of their own money.
/obj/machinery/materials_market/proc/can_order_on_budget(obj/item/card/id/id_card)
	return (ACCESS_CARGO in id_card?.GetAccess())

/// Whether an order placed with `id_card` comes out of the buyer's own pocket, which means a
/// 1.1x surcharge and a crate only their ID can open.
/obj/machinery/materials_market/proc/ordering_privately(obj/item/card/id/id_card)
	return ordering_private || !can_order_on_budget(id_card)

/// The account an order placed here is quoted against, and billed to when it is not private.
/obj/machinery/materials_market/proc/market_account(obj/item/card/id/id_card, is_ordering_private)
	return is_ordering_private ? id_card?.registered_account : SSeconomy.get_dep_account(ACCOUNT_CAR)
