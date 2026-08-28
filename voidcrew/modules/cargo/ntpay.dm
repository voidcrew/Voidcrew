/datum/computer_file/program/nt_pay
	tgui_id = "NtosPayVoidcrew"

	///The bank account swiped onto the tablet, saved here.
	var/obj/item/card/id/inserted_id

/datum/computer_file/program/nt_pay/application_item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(isidcard(tool))
		inserted_id = tool

/datum/computer_file/program/nt_pay/ui_data(mob/user)
	var/list/data = ..()

	data["all_accounts"] = list()
	for(var/obj/item/card/id/cards as anything in current_user.bank_cards)
		data["all_accounts"] += list(list(
			"ref" = REF(cards),
			"name" = cards.name,
		))

	if(inserted_id)
		data["swiped_id"] = list(list(
			"ref" = REF(inserted_id),
			"account" = inserted_id,
		))

	return data

/datum/computer_file/program/nt_pay/ui_act(action, list/params, datum/tgui/ui)
	. = ..()
	//VOIDCREW: upstream replaced computer.computer_id_slot with computer.stored_id + GetID()
	var/obj/item/card/id/computer_id = computer.stored_id?.GetID()
	if(!computer_id?.registered_account)
		return
	switch(action)
		if("add_account")
			if(!inserted_id || (inserted_id.registered_account == computer_id.registered_account))
				return
			// set_account() disconnects the card from its old account and LAZYORs it onto
			// the new one. The hand-rolled version below it used to be wrong twice over:
			// it added `src` (this program datum) instead of the card, and bank_cards is
			// a LAZYLIST now, so a bare += clobbers it with a non-list.
			inserted_id.set_account(computer_id.registered_account)
		if("remove_account")
			var/obj/item/card/id/card = locate(params["removed_account"]) in computer_id.registered_account.bank_cards
			//don't remove yourself
			if(!card || (card == computer_id))
				return
			//only the captain can edit
			if(computer_id.assignment != computer_id.registered_account.account_job.title)
				return
			// clear_account() already LAZYREMOVEs the card from its account's bank_cards.
			card.clear_account()
