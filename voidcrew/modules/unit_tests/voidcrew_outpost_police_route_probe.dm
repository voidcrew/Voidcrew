// DIAGNOSTIC ONLY: prints the planned paths on Quartermain from the concourse to the jail. Not to be kept.
/datum/unit_test/voidcrew_outpost_police_route_probe

/datum/unit_test/voidcrew_outpost_police_route_probe/proc/local(obj/structure/overmap/trader_outpost/outpost, lx, ly)
	var/turf/corner = outpost.template_bottom_left
	return locate(corner.x + lx - 1, corner.y + ly - 1, corner.z)

/datum/unit_test/voidcrew_outpost_police_route_probe/proc/local_text(obj/structure/overmap/trader_outpost/outpost, turf/tile)
	var/turf/corner = outpost.template_bottom_left
	if(!tile)
		return "(nowhere)"
	return "([tile.x - corner.x + 1],[tile.y - corner.y + 1])"

/datum/unit_test/voidcrew_outpost_police_route_probe/proc/path_text(obj/structure/overmap/trader_outpost/outpost, mob/living/walker, atom/target, mintargetdist = 1)
	var/list/access = walker.ai_controller ? walker.ai_controller.get_access() : list()
	var/list/path = get_path_to(walker, target, 250, mintargetdist, access)
	var/list/out = list()
	for(var/turf/tile as anything in path)
		out += local_text(outpost, tile)
	return "[length(path)]: [out.Join(" ")]"

/datum/unit_test/voidcrew_outpost_police_route_probe/proc/probe(obj/structure/overmap/trader_outpost/outpost, label)
	var/datum/outpost_police/police = outpost.police
	var/list/lines = list("== [label]")
	var/datum/outpost_police_cell/cell = length(police.cells) ? police.cells[1] : null
	var/atom/locker = police.get_evidence_locker()
	var/list/starts = list(list(19, 15), list(29, 15), list(33, 21))
	for(var/turf/lift as anything in police.lift_turfs)
		starts += list(list(lift.x - outpost.template_bottom_left.x + 1, lift.y - outpost.template_bottom_left.y + 1))
	for(var/walker_type in list(/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant, /mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell))
		for(var/list/start as anything in starts)
			var/turf/from = local(outpost, start[1], start[2])
			var/mob/living/walker = allocate(walker_type, from)
			if(ispath(walker_type, /mob/living/carbon/human/npc/ambient_npc/outpost/police))
				police.add_officer(walker)
			else
				var/mob/living/carbon/human/npc/ambient_npc/medic = walker
				medic.set_place(SSambient_npcs.outpost_place(outpost))
			lines += "[walker_type] from [local_text(outpost, from)] to locker [local_text(outpost, get_turf(locker))] = [path_text(outpost, walker, locker)]"
			if(cell?.door)
				lines += "[walker_type] from [local_text(outpost, from)] to cell door [local_text(outpost, get_turf(cell.door))] = [path_text(outpost, walker, cell.door)]"
			lines += "[walker_type] from [local_text(outpost, from)] to desk [local_text(outpost, police.desk_turf)] = [path_text(outpost, walker, police.desk_turf, 0)]"
			qdel(walker)
	return lines

/datum/unit_test/voidcrew_outpost_police_route_probe/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(/obj/structure/overmap/trader_outpost/outfitter)
	if(!outpost)
		return
	var/list/lines = list()
	lines += probe(outpost, "normal")
	for(var/checkpoint_id in outpost.checkpoints)
		var/datum/outpost_checkpoint/post = outpost.checkpoints[checkpoint_id]
		lines += "checkpoint [checkpoint_id] guard=[!!post.guard] disabled now"
		post.disable(null, null)
	lines += probe(outpost, "gate down")
	TEST_FAIL(lines.Join("\n"))
