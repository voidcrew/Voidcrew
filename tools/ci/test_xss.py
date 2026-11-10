import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest

from tools.ci.check_xss import added_lines, mask_dm_line, scan_dm, scan_js


def dm(source: str) -> list[int]:
    return [finding.line for finding in scan_dm("test.dm", textwrap.dedent(source).strip("\n"))]


def js(source: str) -> list[int]:
    return [finding.line for finding in scan_js("test.tsx", textwrap.dedent(source).strip("\n"))]


class DmSinkTest(unittest.TestCase):
    def test_raw_param_in_chat(self):
        self.assertEqual(dm('''
            /obj/thing/ui_act(action, params)
            	to_chat(usr, "You named it [params["name"]].")
        '''), [2])

    def test_raw_param_through_a_local_and_span(self):
        self.assertEqual(dm('''
            /obj/thing/ui_act(action, params)
            	var/new_name = trim(params["name"])
            	var/line = "Renamed to [new_name]"
            	to_chat(usr, span_notice(line))
        '''), [4])

    def test_escaped_param_is_fine(self):
        self.assertEqual(dm('''
            /obj/thing/ui_act(action, params)
            	to_chat(usr, "Named [html_encode(params["name"])].")
            	var/clean = reject_bad_text(params["name"])
            	to_chat(usr, "Named [clean].")
        '''), [])

    def test_sanitizing_a_local_in_place_cleans_it(self):
        self.assertEqual(dm('''
            /obj/thing/ui_act(action, params)
            	var/new_name = params["name"]
            	new_name = sanitize(new_name)
            	message_admins("[key_name(usr)] renamed it [new_name]")
        '''), [])

    def test_rejecting_inside_an_if_cleans_it(self):
        self.assertEqual(dm('''
            /obj/thing/ui_act(action, params)
            	var/new_name = params["name"]
            	if(!reject_bad_text(new_name))
            		return
            	to_chat(usr, "Named [new_name].")
        '''), [])

    def test_lookups_and_numbers_are_not_text(self):
        self.assertEqual(dm('''
            /obj/thing/ui_act(action, params)
            	var/datum/pack = GLOB.packs[params["id"]]
            	var/amount = text2num(params["amount"])
            	var/key = params["key"]
            	if(!(key in GLOB.allowed_keys))
            		return
            	to_chat(usr, "Bought [amount] of [pack] with [GLOB.names[params["id"]]] for [key].")
        '''), [])

    def test_raw_input_and_unencoded_tgui_input(self):
        self.assertEqual(dm('''
            /mob/proc/ask()
            	var/text = input(src, "Say what?") as text|null
            	visible_message("[src] says [text]")
            	var/other = tgui_input_text(src, "Name", "Name", encode = FALSE)
            	priority_announce(other)
            	var/fine = tgui_input_text(src, "Name", "Name")
            	priority_announce(fine)
        '''), [3, 5])

    def test_href_list_and_browse(self):
        self.assertEqual(dm('''
            /datum/panel/Topic(href, href_list)
            	var/dat = "<b>[href_list["note"]]</b>"
            	usr << browse(dat, "window=x")
        '''), [3])

    def test_storing_raw_text_on_an_object(self):
        self.assertEqual(dm('''
            /obj/machinery/console/ui_act(action, params)
            	ship.memo = params["memo"]
            	name = params["name"]
            	selected_tab = params["tab"]
        '''), [2, 3])

    def test_taint_resets_between_procs(self):
        self.assertEqual(dm('''
            /obj/a/proc/one(list/params)
            	var/text = params["text"]
            /obj/a/proc/two(text)
            	to_chat(usr, text)
        '''), [])

    def test_strings_and_comments_are_not_code(self):
        self.assertEqual(dm('''
            /obj/thing/ui_act(action, params)
            	var/amount = params["amount"]
            	say("Check the amount and try again.") // to_chat(usr, amount)
        '''), [])

    def test_suppression_needs_a_reason(self):
        self.assertEqual(dm('''
            /obj/thing/ui_act(action, params)
            	// xss-safe: only admins reach this and they may send HTML
            	to_chat(usr, params["html"])
            	to_chat(usr, params["html"]) // xss-safe:
        '''), [4])

    def test_mask_keeps_interpolation_and_keys(self):
        self.assertEqual(
            mask_dm_line('to_chat(a, "hi [params["x"]] there") // note'),
            'to_chat(a, "###[params["x"]]######") ',
        )


class JsSinkTest(unittest.TestCase):
    def test_raw_html_sinks(self):
        self.assertEqual(js('''
            <div dangerouslySetInnerHTML={{ __html: data.text }} />
            node.innerHTML = message;
            <Box html={data.desc} />
            el.insertAdjacentHTML('beforeend', x);
            <a href="javascript:void(0)">x</a>
        '''), [1, 2, 3, 4, 5])

    def test_purified_and_reviewed_lines_pass(self):
        self.assertEqual(js('''
            node.innerHTML = DOMPurify.sanitize(message);
            // xss-safe: static string, no data
            node.innerHTML = '<br>';
            <Box>{data.desc}</Box>
            if (node.innerHTML === old) {}
        '''), [])


class DiffModeTest(unittest.TestCase):
    def test_only_added_lines_are_reported(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)

            def run(*args):
                subprocess.run(["git", *args], cwd=root, check=True, capture_output=True)

            run("init", "-q", "-b", "master")
            run("config", "user.email", "ci@example.com")
            run("config", "user.name", "ci")
            source = root / "voidcrew" / "thing.dm"
            source.parent.mkdir()
            source.write_text('/obj/a/ui_act(action, params)\n\tto_chat(usr, params["old"])\n', encoding="utf-8")
            run("add", ".")
            run("commit", "-q", "-m", "base")
            run("checkout", "-q", "-b", "feature")
            with source.open("a", encoding="utf-8") as handle:
                handle.write('\tto_chat(usr, params["new"])\n')
            run("commit", "-qam", "change")

            previous = os.getcwd()
            os.chdir(root)
            try:
                self.assertEqual(added_lines("master"), {"voidcrew/thing.dm": {3}})
            finally:
                os.chdir(previous)


if __name__ == "__main__":
    unittest.main()
