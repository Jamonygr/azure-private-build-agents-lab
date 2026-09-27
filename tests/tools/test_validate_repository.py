"""Behavior tests for repository documentation and source-safety checks."""

import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest import mock


TOOL_PATH = Path(__file__).resolve().parents[2] / "tools" / "validate_repository.py"
SPEC = importlib.util.spec_from_file_location("validate_repository", str(TOOL_PATH))
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


class RepositoryFixture(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.source = self.write("docs/readme.md", "# Read me\n")
        for number in range(1, 11):
            self.write("wiki/exercises/{:02d}-exercise.md".format(number), "# Exercise {}\n".format(number))

    def write(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path


class LocalLinkTests(RepositoryFixture):
    def test_nested_relative_link_and_percent_encoded_filename(self):
        self.write("docs/reference/My guide.md", "# A guide\n")
        self.source.write_text("[Guide](reference/My%20guide.md)\n", encoding="utf-8")
        self.assertEqual([], validator.validate_markdown(self.root, self.source))

    def test_missing_local_file_is_actionable(self):
        self.source.write_text("# Links\n\n[Missing](missing.md)\n", encoding="utf-8")
        issues = validator.validate_markdown(self.root, self.source)
        self.assertEqual(1, len(issues))
        self.assertIn("docs/readme.md:3", issues[0])
        self.assertIn("missing.md", issues[0])

    def test_path_traversal_is_rejected_even_if_target_exists(self):
        with self.assertRaisesRegex(ValueError, "escapes"):
            validator.local_destination(self.root, self.source, "../../outside.md")

    def test_encoded_path_traversal_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "escapes"):
            validator.local_destination(self.root, self.source, "%2e%2e/%2e%2e/outside.md")

    def test_external_urls_and_fragments_do_not_require_network(self):
        self.source.write_text("[Web](https://example.invalid/page#section)\n[Mail](mailto:test@example.invalid)\n[Heading](#read-me)\n", encoding="utf-8")
        self.assertEqual([], validator.validate_markdown(self.root, self.source))

    def test_fenced_examples_are_not_treated_as_live_links(self):
        self.source.write_text("~~~markdown\n[Example](nonexistent.md)\n~~~\n`[Inline](absent.md)`\n", encoding="utf-8")
        self.assertEqual([], validator.validate_markdown(self.root, self.source))

    def test_reference_links_and_html_images_are_validated(self):
        self.source.write_text('[guide]: missing.md\n<img src="missing.svg" alt="Missing">\n', encoding="utf-8")
        self.assertEqual(2, len(validator.validate_markdown(self.root, self.source)))

    def test_optional_anchor_checks_preserve_duplicate_heading_suffixes(self):
        self.write("docs/target.md", "# Topic\n## Repeated heading\n## Repeated heading\n")
        self.source.write_text("[Valid](target.md#repeated-heading-1)\n[Invalid](target.md#missing)\n", encoding="utf-8")
        issues = validator.validate_markdown(self.root, self.source, check_anchors=True)
        self.assertEqual(1, len(issues))
        self.assertIn("#missing", issues[0])

    def test_heading_code_text_contributes_to_anchor(self):
        self.write("docs/target.md", "## Run `Plan` before `Apply`\n")
        self.source.write_text("[Commands](target.md#run-plan-before-apply)\n", encoding="utf-8")
        self.assertEqual([], validator.validate_markdown(self.root, self.source, check_anchors=True))


class SvgTests(RepositoryFixture):
    def test_valid_accessible_svg(self):
        svg = self.write("docs/diagram.svg", '<svg xmlns="http://www.w3.org/2000/svg" aria-labelledby="title description"><title id="title">Topology</title><desc id="description">A private network.</desc></svg>')
        self.assertEqual([], validator.validate_svg(self.root, svg))

    def test_malformed_svg_is_reported(self):
        svg = self.write("docs/diagram.svg", '<svg xmlns="http://www.w3.org/2000/svg"><g></svg>')
        self.assertIn("malformed SVG", validator.validate_svg(self.root, svg)[0])

    def test_missing_accessible_description_is_reported(self):
        svg = self.write("docs/diagram.svg", '<svg xmlns="http://www.w3.org/2000/svg"><title>Topology</title></svg>')
        self.assertIn("nonempty accessible desc", validator.validate_svg(self.root, svg)[0])

    def test_broken_accessibility_id_is_reported(self):
        svg = self.write("docs/diagram.svg", '<svg xmlns="http://www.w3.org/2000/svg" aria-labelledby="missing"><title>Topology</title><desc>Network</desc></svg>')
        self.assertIn("references missing ID", validator.validate_svg(self.root, svg)[0])


class RepositoryPolicyTests(RepositoryFixture):
    def test_new_pipeline_file_is_rejected(self):
        self.write("pipelines/workload.yml", "trigger: none\n")
        issues = validator.validate_repository(self.root)
        self.assertTrue(any("pipeline/workflow files" in issue for issue in issues))

    def test_github_workflow_is_rejected(self):
        self.write(".github/workflows/check.yml", "name: checks\n")
        self.assertTrue(any("pipeline/workflow files" in issue for issue in validator.validate_repository(self.root)))

    def test_exclusion_statement_is_allowed(self):
        self.write("README.md", "# Lab\nPipelines are excluded. No serviceConnectionName setup is provided.\n")
        self.assertEqual([], validator.validate_repository(self.root))

    def test_ignored_local_state_is_not_read_or_flagged(self):
        self.write(".local/state/foundation.tfstate", "private-local-state")
        self.assertEqual([], validator.validate_repository(self.root))

    def test_force_tracked_local_state_is_flagged_without_reading(self):
        with mock.patch.object(validator, "tracked_paths", return_value=[Path(".local/state/foundation.tfstate")]):
            issues = validator.validate_repository(self.root)
        self.assertTrue(any("must not be tracked" in issue for issue in issues))

    def test_unignored_state_is_rejected(self):
        self.write("foundation.tfstate.backup", "private-state")
        self.assertTrue(any("state and plan artifacts" in issue for issue in validator.validate_repository(self.root)))

    def test_secret_diagnostic_never_echoes_credential(self):
        token = "ghp_" + "A" * 40
        self.write("README.md", "token = " + token)
        issues = validator.validate_repository(self.root)
        self.assertTrue(any("possible GitHub token" in issue for issue in issues))
        self.assertFalse(any(token in issue for issue in issues))

    def test_missing_exercise_is_reported(self):
        (self.root / "wiki/exercises/04-exercise.md").unlink()
        self.assertTrue(any("01 through 10" in issue for issue in validator.validate_repository(self.root)))


if __name__ == "__main__":
    unittest.main()
