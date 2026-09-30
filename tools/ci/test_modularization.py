import contextlib
from collections import Counter
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from tools.ci.check_modularization import (
    analyze, check, check_source, escape, load_exceptions, main,
    placement_destination,
)


class MarkerTests(unittest.TestCase):
    def violations(self, before, after, additions=None, *, frontend=False):
        return check_source("code/example.dm", analyze(before, frontend=frontend), analyze(after, frontend=frontend),
                            [Counter(lines) for lines in additions or []])

    def test_unmarked_edit_fails(self):
        self.assertTrue(self.violations('/obj/example\n\tvalue = 1\n', '/obj/example\n\tvalue = 2\n'))

    def test_inline_marker_covers_one_line(self):
        self.assertFalse(self.violations('/obj/example\n\tvalue = 1\n', '/obj/example\n\tvalue = 2 // VOIDCREW EDIT: enable the feature\n'))

    def test_preceding_marker_does_not_cover_a_second_code_line(self):
        result = self.violations('', '// VOIDCREW EDIT: feature hook\ncall_hook()\nunmarked()\n')
        self.assertEqual([finding.line for finding in result], [3])

    def test_preceding_marker_covers_a_continued_statement(self):
        before = 'AddElement(\\\n\tforce = 30,\\\n\tmultiplier = 0.3,\\\n)\nunrelated()\n'
        after = '// VOIDCREW EDIT CHANGE - multiplier was 0.3\n' + before.replace('0.3', '0.75')
        self.assertFalse(self.violations(before, after))
        # The statement ends at the first line without a continuation.
        result = self.violations(before, after.replace('unrelated()', 'changed()'))
        self.assertEqual([finding.line for finding in result], [6])

    def test_reason_words_are_not_marker_boundaries(self):
        self.assertFalse(self.violations('', '// VOIDCREW EDIT: end the round after a win\nfinish_round()\n'))

    def test_start_end_and_legacy_begin_blocks(self):
        for opening, ending in [('START', 'END'), ('BEGIN', 'END')]:
            with self.subTest(opening=opening):
                self.assertFalse(self.violations('', f'// VOIDCREW EDIT ADDITION {opening} - hook\none()\ntwo()\n// VOIDCREW EDIT ADDITION {ending}\n'))
        self.assertFalse(self.violations('', '// START VOIDCREW EDIT\none()\n// END VOIDCREW EDIT\n'))

    def test_existing_balanced_block_covers_new_edits(self):
        before = '// VOIDCREW EDIT START\none()\n// VOIDCREW EDIT END\n'
        self.assertFalse(self.violations(before, before.replace('one()', 'two()\nthree()')))

    def test_unclosed_marker_does_not_exempt_rest_of_file(self):
        result = self.violations('', '// VOIDCREW EDIT START\nunmarked()\n')
        self.assertEqual(len(result), 2)
        self.assertIn('matching END', result[0].message)

    def test_new_orphan_end_is_rejected(self):
        self.assertEqual(len(self.violations('', '// VOIDCREW EDIT END\n')), 1)

    def test_removing_one_boundary_is_rejected(self):
        before = '// VOIDCREW EDIT START\none()\n// VOIDCREW EDIT END\n'
        self.assertTrue(self.violations(before, 'one()\n// VOIDCREW EDIT END\n'))

    def test_preexisting_orphan_does_not_block_unrelated_marked_edit(self):
        before = '// VOIDCREW EDIT END\none()\n'
        after = before.replace('one()', 'two() // VOIDCREW EDIT: hook')
        self.assertFalse(self.violations(before, after))

    def test_new_duplicate_orphan_is_not_grandfathered(self):
        before = '// VOIDCREW EDIT END\n'
        self.assertEqual(len(self.violations(before, before + before)), 1)

    def test_marker_in_string_is_not_a_comment(self):
        for value in ['"// VOIDCREW EDIT"', "'// VOIDCREW EDIT'", '`// VOIDCREW EDIT`']:
            with self.subTest(value=value):
                self.assertTrue(self.violations('', f'var/message = {value}\n'))
        self.assertTrue(self.violations('', 'var/message = {"\n// VOIDCREW EDIT START\n"}\nunmarked()\n'))

    def test_multiline_comments_jsx_and_styles(self):
        self.assertFalse(self.violations('', '/* VOIDCREW EDIT START */\nconst view = <Box />;\n/* VOIDCREW EDIT END */\n'))
        self.assertFalse(self.violations('', '{/* VOIDCREW EDIT START */}\n<Box />\n{/* VOIDCREW EDIT END */}\n'))
        self.assertFalse(self.violations('', '/* VOIDCREW EDIT: override\n * shared layout\n */\n.foo { color: red; }\n'))

    def test_marker_after_escaped_quote_is_recognized(self):
        self.assertFalse(self.violations('', 'name = "a \\"b" // VOIDCREW EDIT: label\n'.replace('\\\\', '\\')))

    def test_interpolated_strings_do_not_create_fake_markers(self):
        values = ['"[call("// VOIDCREW EDIT")]"',
                  '"[items["key"]] // VOIDCREW EDIT"',
                  '`outer ${call(`// VOIDCREW EDIT`)} text`']
        for value in values:
            with self.subTest(value=value):
                source = f'value = {value}\n'
                self.assertTrue(self.violations('', source))
                self.assertFalse(self.violations('', source.rstrip() + ' // VOIDCREW EDIT: value\n'))

    def test_dm_multiline_string_keeps_literal_quotes_and_interpolation(self):
        source = 'value = {"\n<a href="url">\n[call("name")]\n// VOIDCREW EDIT\n"}\n'
        self.assertFalse(any(analyze(source).comments))
        self.assertTrue(self.violations('', source))
        self.assertFalse(self.violations('', '// VOIDCREW EDIT START\n' + source + '// VOIDCREW EDIT END\n'))

    def test_continued_string_does_not_create_fake_marker(self):
        source = 'value = "hello\\\n// VOIDCREW EDIT"\n'
        for frontend in (False, True):
            with self.subTest(frontend=frontend):
                self.assertTrue(self.violations('', source, frontend=frontend))
                self.assertFalse(any(analyze(source, frontend=frontend).comments))

    def test_frontend_quoted_object_key_is_not_a_dm_multiline_string(self):
        source = 'const value = {"key": 1}; // VOIDCREW EDIT: setting\nunmarked();\n'
        self.assertEqual([f.line for f in self.violations('', source, frontend=True)], [2])

    def test_frontend_regex_does_not_create_fake_marker(self):
        for prefix in ['const pattern = ', 'const pattern = () => ', 'return ']:
            source = prefix + '/[//] VOIDCREW EDIT/;\n'
            with self.subTest(prefix=prefix):
                self.assertTrue(self.violations('', source, frontend=True))
                self.assertFalse(self.violations('', source.rstrip() + ' // VOIDCREW EDIT: pattern\n', frontend=True))
        self.assertFalse(self.violations('', 'const value = a / b; // VOIDCREW EDIT: ratio\n', frontend=True))

    def test_dm_raw_strings_do_not_create_fake_markers(self):
        for value in ['@"[// VOIDCREW EDIT]"', '@#"[// VOIDCREW EDIT]"#',
                      '@{"\n[// VOIDCREW EDIT]\n"}']:
            with self.subTest(value=value):
                source = f'value = {value}\n'
                self.assertFalse(any(analyze(source).comments))
                self.assertTrue(self.violations('', source))

    def test_jsx_apostrophes_do_not_hide_inline_comments(self):
        for prose in ["don't hide this", "the players' ship"]:
            with self.subTest(prose=prose):
                source = '<Box>' + prose + '</Box> {/* VOIDCREW EDIT: text */}\n'
                self.assertFalse(self.violations('', source, frontend=True))

    def test_same_line_boundaries_are_paired(self):
        self.assertFalse(self.violations('', '/* VOIDCREW EDIT START */ one(); /* VOIDCREW EDIT END */\n'))

    def test_commenting_out_code_requires_marker(self):
        before = 'one()\ntwo()\n'
        self.assertTrue(self.violations(before, '/*\n' + before + '*/\n'))
        self.assertFalse(self.violations(before, '/* VOIDCREW EDIT: removed hooks\n' + before + '*/\n'))

    def test_uncommenting_code_requires_marker(self):
        after = 'one()\ntwo()\n'
        self.assertTrue(self.violations('/*\n' + after + '*/\n', after))
        self.assertFalse(self.violations('/*\n' + after + '*/\n', '// VOIDCREW EDIT START\n' + after + '// VOIDCREW EDIT END\n'))

    def test_multiline_literal_whitespace_is_code(self):
        before = 'value = {"\n \n"}\n'
        self.assertTrue(self.violations(before, before.replace('\n \n', '\n  \n')))

    def test_deletion_explanation_uses_full_comment_context(self):
        before = '/* note\n */ one()\n'
        after = '/* note\n * VOIDCREW EDIT: removed hook\n */\n'
        self.assertFalse(self.violations(before, after))

    def test_comment_only_change_needs_no_marker(self):
        self.assertFalse(self.violations('call()\n', '// Clarification\ncall()\n'))
        self.assertFalse(self.violations('call() // old explanation\n', 'call() // clearer explanation\n'))

    def test_inline_string_changes_still_require_a_marker(self):
        self.assertTrue(self.violations('name = "// old"\n', 'name = "// new"\n'))

    def test_dm_indentation_change_still_requires_a_marker(self):
        self.assertTrue(self.violations('/proc/example()\n\tif(flag)\n\t\tact()\n', '/proc/example()\n\tif(flag)\n\tact()\n'))

    def test_jsx_comment_can_mark_the_following_single_line(self):
        self.assertFalse(self.violations('', '{/* VOIDCREW EDIT: hook */}\n<Module />\n'))

    def test_unmarked_deletion_fails(self):
        self.assertTrue(self.violations('/obj/example\n\tvalue = 1\n', '/obj/example\n'))

    def test_deletion_with_explanation_passes(self):
        self.assertFalse(self.violations('/obj/example\n\tvalue = 1\n', '/obj/example\n\t// VOIDCREW EDIT: inherit the shared default\n'))

    def test_deleting_marked_fork_code_passes(self):
        self.assertFalse(self.violations('// VOIDCREW EDIT START\nhook()\n// VOIDCREW EDIT END\n', ''))

    def test_removing_code_inside_retained_block_passes(self):
        self.assertFalse(self.violations('// VOIDCREW EDIT START\nhook()\n// VOIDCREW EDIT END\n', '// VOIDCREW EDIT START\n// VOIDCREW EDIT END\n'))

    def test_neighboring_marker_does_not_cover_a_deletion(self):
        before = 'first() // VOIDCREW EDIT: hook\nremoved()\nlast() // VOIDCREW EDIT: hook\n'
        self.assertTrue(self.violations(before, before.replace('removed()\n', '')))

    def test_exact_module_move_passes_but_similar_body_does_not(self):
        before = '/proc/feature()\n\treturn 42\n'
        self.assertFalse(self.violations(before, '', [['/proc/feature()', 'return 42']]))
        self.assertTrue(self.violations(before, '', [['/proc/feature()', 'return 43']]))

    def test_separate_files_cannot_fake_a_module_move(self):
        self.assertTrue(self.violations('one()\ntwo()\n', '', [['one()'], ['two()']] ))

    def test_regrouped_type_declarations_can_move_together(self):
        self.assertFalse(self.violations('/obj/example\nvalue = 1\n/obj/example/act()\nreturn 42\n', '',
                                         [['/obj/example/act()', 'return 42', '/obj/example', 'value = 1']]))

    def test_module_move_must_preserve_duplicate_lines(self):
        self.assertTrue(self.violations('one()\none()\n', '', [['one()']] ))

    def test_one_module_addition_cannot_excuse_two_deleted_hunks(self):
        before = 'one()\nkeep()\none()\n'
        self.assertEqual(len(self.violations(before, 'keep()\n', [['one()']])), 1)


class PolicyTests(unittest.TestCase):
    def test_upstream_new_files_need_modular_locations(self):
        paths = ['code/feature.dm', 'code/__DEFINES/feature.dm', 'code/modules/unit_tests/feature.dm',
                 'tgui/packages/tgui/interfaces/Feature.tsx', 'tgui/packages/tgui-panel/chat/feature.ts',
                 'icons/feature.dmi', 'sound/feature.ogg', '_maps/shuttles/feature.dmm']
        for path in paths:
            with self.subTest(path=path):
                self.assertIsNotNone(placement_destination(path))

    def test_modular_and_infrastructure_locations_are_allowed(self):
        paths = ['voidcrew/modules/example/code.dm', 'voidcrew/edits/turf.dm', 'voidcrew/_DEFINES/example.dm',
                 'tgui/packages/voidcrew_tgui/interfaces/Example.tsx', '_maps/voidcrew/ships/example.dmm',
                 'tools/ci/example.py', '.github/workflows/example.yml', 'tgstation.dme',
                 'code/modules/tgs/v5/example.dm']
        for path in paths:
            with self.subTest(path=path):
                self.assertIsNone(placement_destination(path))

    def test_case_variant_source_suffixes_still_need_modular_locations(self):
        for path in ['code/feature.DM', '_maps/shuttles/feature.DMM']:
            with self.subTest(path=path):
                self.assertIsNotNone(placement_destination(path))

    def test_exception_requires_exact_path_reason_and_known_rules(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'exceptions.json'
            valid = {'code/example.dm': {'rules': ['placement'], 'reason': 'Mirrors a vendored dependency'}}
            path.write_text(json.dumps(valid), encoding='utf-8')
            self.assertEqual(load_exceptions(path), {'code/example.dm': {'placement'}})
            for invalid in [[], {'code/*': valid['code/example.dm']}, {'../example.dm': valid['code/example.dm']},
                            {'code/example.dm': {'rules': ['placement'], 'reason': ''}},
                            {'code/example.dm': {'rules': ['everything'], 'reason': 'x'}}]:
                with self.subTest(invalid=invalid):
                    path.write_text(json.dumps(invalid), encoding='utf-8')
                    with self.assertRaises(ValueError):
                        load_exceptions(path)

    def test_annotations_escape_control_characters(self):
        self.assertEqual(escape('a%,:\n\r', property_value=True), 'a%25%2C%3A%0A%0D')


class GitIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.hooks = self.root / 'empty-hooks'
        self.hooks.mkdir()
        self.git('init', '-q')
        self.git('config', 'user.name', 'Test fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'core.autocrlf', 'false')
        self.git('config', 'commit.gpgsign', 'false')
        self.write('code/example.dm', '/obj/example\n\tvalue = 1\n')
        self.write('tools/ci/modularization_exceptions.json', '{}\n')
        self.base = self.commit()

    def git(self, *args):
        return subprocess.check_output(['git', '-c', f'core.hooksPath={self.hooks}', *args], cwd=self.root, stderr=subprocess.PIPE, text=True).strip()

    def write(self, path, text):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(text, encoding='utf-8')

    def commit(self):
        self.git('add', '.')
        self.git('commit', '-qm', 'Fixture revision')
        return self.git('rev-parse', 'HEAD')

    def test_committed_change_fails_with_path_and_line(self):
        self.write('code/example.dm', '/obj/example\n\tvalue = 2\n')
        findings = check(self.root, self.base, self.commit())
        self.assertEqual([(f.path, f.line, f.rule) for f in findings], [('code/example.dm', 2, 'markers')])

    def test_frontend_lexer_selected_for_committed_tgui_sources(self):
        path = 'tgui/packages/tgui/interfaces/Example.tsx'
        self.write(path, 'const pattern = /old/;\n')
        base = self.commit()
        self.write(path, 'const pattern = /[//] VOIDCREW EDIT/;\n')
        self.assertEqual([(f.path, f.rule) for f in check(self.root, base, self.commit())], [(path, 'markers')])

    def test_uncommitted_edits_are_not_in_the_pr_diff(self):
        self.write('code/example.dm', '/obj/example\n\tvalue = 2\n')
        self.assertEqual(check(self.root, self.base, 'HEAD'), [])

    def test_new_upstream_file_fails_even_with_markers(self):
        self.write('code/new feature.dm', '// VOIDCREW EDIT START\n/obj/new_feature\n// VOIDCREW EDIT END\n')
        findings = check(self.root, self.base, self.commit())
        self.assertEqual([(f.path, f.rule) for f in findings], [('code/new feature.dm', 'placement')])

    def test_move_to_module_with_spaces_in_filename_passes(self):
        self.write('voidcrew/edits/example moved.dm', (self.root / 'code/example.dm').read_text())
        (self.root / 'code/example.dm').unlink()
        self.assertEqual(check(self.root, self.base, self.commit()), [])

    def test_extract_proc_into_existing_module_passes(self):
        self.write('code/example.dm', '/proc/feature()\n\treturn 42\n\n/obj/example\n\tvalue = 1\n')
        self.write('voidcrew/modules/example/main.dm', '/obj/module_example\n')
        base = self.commit()
        self.write('code/example.dm', '/obj/example\n\tvalue = 1\n')
        self.write('voidcrew/modules/example/main.dm', '/obj/module_example\n\n/proc/feature()\n\treturn 42\n')
        self.assertEqual(check(self.root, base, self.commit()), [])

    def test_preexisting_module_code_does_not_excuse_an_upstream_deletion(self):
        self.write('voidcrew/modules/example/main.dm', '/obj/example\n\tvalue = 1\n')
        base = self.commit()
        (self.root / 'code/example.dm').unlink()
        self.assertEqual(check(self.root, base, self.commit())[0].rule, 'markers')

    def test_one_module_addition_cannot_excuse_deletions_in_two_files(self):
        self.write('code/another.dm', '/obj/another\n\tvalue = 1\n')
        base = self.commit()
        self.write('voidcrew/modules/example/main.dm', '/obj/example\n\tvalue = 1\n')
        self.write('code/example.dm', '/obj/example\n')
        self.write('code/another.dm', '/obj/another\n')
        self.assertEqual(len(check(self.root, base, self.commit())), 1)

    def test_move_from_module_into_upstream_fails(self):
        self.write('voidcrew/modules/example/main.dm', '/obj/module_example\n')
        base = self.commit()
        self.write('code/moved.dm', (self.root / 'voidcrew/modules/example/main.dm').read_text())
        (self.root / 'voidcrew/modules/example/main.dm').unlink()
        self.assertEqual(check(self.root, base, self.commit())[0].rule, 'placement')

    def test_exact_exception_does_not_allow_another_file(self):
        self.write('code/allowed.dm', '/obj/allowed\n')
        self.write('code/not_allowed.dm', '/obj/not_allowed\n')
        result = check(self.root, self.base, self.commit(), {'code/allowed.dm': {'placement', 'markers'}})
        self.assertEqual([f.path for f in result], ['code/not_allowed.dm'])

    def test_base_updates_do_not_become_pr_violations(self):
        # Match CI's shallow PR merge checkout: compare the merge's first parent.
        self.git('checkout', '-qb', 'feature')
        self.write('voidcrew/modules/example/new.dm', '/obj/module_example\n')
        self.commit()
        self.git('checkout', '-qb', 'base-update', self.base)
        self.write('code/unrelated.dm', '/obj/upstream_update\n')
        self.commit()
        self.git('merge', '--no-ff', '-qm', 'PR merge', 'feature')
        self.assertEqual(check(self.root, 'HEAD^1', 'HEAD'), [])
        shallow = self.root / 'shallow-check'
        self.git('clone', '--depth', '2', '--no-local', self.root.as_uri(), str(shallow))
        self.assertEqual(check(shallow, 'HEAD^1', 'HEAD'), [])

    def test_cli_exit_status_and_github_annotations(self):
        self.write('code/example.dm', '/obj/example\n\tvalue = 2\n')
        self.commit()
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = main(['--repo', str(self.root), '--base', self.base, '--github'])
        self.assertEqual(status, 1)
        self.assertIn('::error file=code/example.dm,line=2::', output.getvalue())
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(main(['--repo', str(self.root), '--base', 'missing-ref']), 2)
            self.assertEqual(main(['--repo', str(self.root), '--base', 'HEAD']), 0)


if __name__ == '__main__':
    unittest.main()
