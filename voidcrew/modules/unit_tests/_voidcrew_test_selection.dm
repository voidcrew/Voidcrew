/// A test that only runs when asked for by name (test_only, or TEST_FOCUS): soaks and other
/// slow checks that would stretch a general run by minutes. Subtypes are the tests; this
/// parent never runs.
/datum/unit_test/voidcrew_opt_in
	abstract_type = /datum/unit_test/voidcrew_opt_in

/// Picks tests at world start from world.params, so one test build can be split across several
/// isolated worlds at once. Every param is optional; with none set every test runs.
///   test_only  - comma separated type path prefixes; only matching tests run (and the only way to run a voidcrew_opt_in test)
///   test_skip  - comma separated type path prefixes; matching tests are skipped
///   test_shard - "k/n"; tests that walk a long list (every_ship) take every nth entry from k
/proc/voidcrew_select_unit_tests(list/tests)
	var/list/only = splittext(world.params["test_only"] || "", ",")
	var/list/skip = splittext(world.params["test_skip"] || "", ",")
	only -= ""
	skip -= ""
	// Opt-in tests are slow soaks: a general run leaves them out, and a TEST_FOCUS or a
	// test_only that names them brings them in.
	var/list/kept = list()
	for(var/test_type in tests)
		if(ispath(test_type, /datum/unit_test/voidcrew_opt_in))
			var/datum/unit_test/opt_in_type = test_type
			if(!initial(opt_in_type.focus) && !(length(only) && voidcrew_test_path_matches("[test_type]", only)))
				continue
		kept += test_type
	tests = kept
	if(!length(only) && !length(skip))
		return tests
	var/list/selected = list()
	for(var/test_type in tests)
		var/path_text = "[test_type]"
		if(length(only) && !voidcrew_test_path_matches(path_text, only))
			continue
		if(length(skip) && voidcrew_test_path_matches(path_text, skip))
			continue
		selected += test_type
	return selected

/proc/voidcrew_test_path_matches(path_text, list/prefixes)
	for(var/prefix in prefixes)
		if(path_text == prefix || findtext(path_text, "[prefix]/", 1, length(prefix) + 2))
			return TRUE
	return FALSE

/// Whether the entry at this 1-based position belongs to this world's shard.
/proc/voidcrew_test_shard_takes(position)
	var/list/shard = splittext(world.params["test_shard"] || "", "/")
	if(length(shard) != 2)
		return TRUE
	var/index = text2num(shard[1])
	var/count = text2num(shard[2])
	if(!index || !count)
		return TRUE
	return (position - 1) % count == index - 1
