//Please use mob or src (not usr) in these procs. This way they can be called in the same fashion as procs.
/client/verb/wiki()
	set name = "Wiki"
	set desc = "Brings you to the Wiki"
	set category = "OOC"

	var/wikiurl = CONFIG_GET(string/wikiurl)
	if(!wikiurl)
		to_chat(src, span_danger("The wiki URL is not set in the server configuration."))
		return

	//Voidcrew's wiki is a static site with its own search box on the page, so there is
	//no MediaWiki search URL to build - just open it.
	DIRECT_OUTPUT(src, link(wikiurl))

/client/verb/forum()
	set name = "forum"
	set desc = "Visit the forum."
	set hidden = TRUE

	var/forumurl = CONFIG_GET(string/forumurl)
	if(!forumurl)
		to_chat(src, span_danger("The forum URL is not set in the server configuration."))
		return
	DIRECT_OUTPUT(src, link(forumurl))

/client/verb/rules()
	set name = "rules"
	set desc = "Show Server Rules."
	set hidden = TRUE

	var/rulesurl = CONFIG_GET(string/rulesurl)
	if(!rulesurl)
		to_chat(src, span_danger("The rules URL is not set in the server configuration."))
		return
	DIRECT_OUTPUT(src, link(rulesurl))

/client/verb/github()
	set name = "github"
	set desc = "Visit Github"
	set hidden = TRUE

	var/githuburl = CONFIG_GET(string/githuburl)
	if(!githuburl)
		to_chat(src, span_danger("The Github URL is not set in the server configuration."))
		return
	DIRECT_OUTPUT(src, link(githuburl))

/client/verb/reportissue()
	set name = "report-issue"
	set desc = "Report an issue"

	var/githuburl = CONFIG_GET(string/githuburl)
	if(!githuburl)
		to_chat(src, span_danger("The Github URL is not set in the server configuration."))
		return

	var/testmerge_data = GLOB.revdata.testmerge
	var/has_testmerge_data = (length(testmerge_data) != 0)

	var/message = "This will open the Github issue reporter in your browser. Are you sure?"
	if(has_testmerge_data)
		message += "<br>The following experimental changes are active and are probably the cause of any new or sudden issues you may experience. If possible, please try to find a specific thread for your issue instead of posting to the general issue tracker:<br>"
		message += GLOB.revdata.GetTestMergeInfo(FALSE)

	// We still use tg_alert here because some people were concerned that if someone wanted to report that tgui wasn't working
	// then the report issue button being tgui-based would be problematic.
	if(tg_alert(src, message, "Report Issue", "Yes", "No") != "Yes")
		return

	var/base_link = githuburl + "/issues/new?template=bug_report_form.yml"
	var/list/concatable = list(base_link)

	var/client_version = "[byond_version].[byond_build]"
	concatable += ("&reporting-version=" + client_version)

	// the way it works is that we use the ID's that are baked into the template YML and replace them with values that we can collect in game.
	if(GLOB.round_id)
		concatable += ("&round-id=" + GLOB.round_id)

	// Insert testmerges
	if(has_testmerge_data)
		var/list/all_tms = list()
		for(var/entry in testmerge_data)
			var/datum/tgs_revision_information/test_merge/tm = entry
			all_tms += "- \[[tm.title]\]([githuburl]/pull/[tm.number])"
		var/all_tms_joined = jointext(all_tms, "\n")

		concatable += ("&test-merges=" + url_encode(all_tms_joined))

	DIRECT_OUTPUT(src, link(jointext(concatable, "")))

/client/verb/changelog()
	set name = "Changelog"
	set category = "OOC"

	if(!GLOB.changelog_tgui)
		GLOB.changelog_tgui = new /datum/changelog()

	GLOB.changelog_tgui.ui_interact(mob)
	if(prefs.lastchangelog != GLOB.changelog_hash)
		prefs.lastchangelog = GLOB.changelog_hash
		prefs.save_preferences()
		winset(src, "infobuttons.changelog", "font-style=;")

/client/verb/hotkeys_help()
	set name = "Hotkeys Help"
	set category = "OOC"

	if(!GLOB.hotkeys_tgui)
		GLOB.hotkeys_tgui = new /datum/hotkeys_help()

	GLOB.hotkeys_tgui.ui_interact(mob)
