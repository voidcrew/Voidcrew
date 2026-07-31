/obj/item/experi_scanner/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(voidcrew_multitool_link_experiment_handler(src, user, tool))
		return TRUE
	return ..()
