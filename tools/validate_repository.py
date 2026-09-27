#!/usr/bin/env python3
"""Validate local repository content without network access or third-party packages.

Run ``python tools/validate_repository.py --check`` from any directory. This
checks documentation targets, SVG accessibility, curriculum completeness and
excluded artifacts. Add ``--anchors`` for Markdown heading-fragment checks.
Generated Terraform references are checked separately with terraform-docs.
This intentionally complements, rather than replaces, the full secret scanner.
"""

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Iterable, List, Optional, Set, Tuple
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET


EXCLUDED_DIRECTORIES = {
    ".git", ".terraform", ".local", ".cache", ".pytest_cache", "__pycache__",
    ".venv", "venv", "node_modules",
}
SOURCE_EXTENSIONS = {".md", ".tf", ".hcl", ".ps1", ".psm1", ".py", ".json", ".yml", ".yaml", ".txt"}
HIGH_CONFIDENCE_SECRETS = (
    ("private key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----")),
    ("GitHub token", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b|\bgithub_pat_[A-Za-z0-9_]{50,}\b")),
    ("Storage account key", re.compile(r"\bAccountKey=[A-Za-z0-9+/]{80,}={0,2}")),
    ("signed SAS URL", re.compile(r"[?&]sig=[A-Za-z0-9%+/]{30,}")),
)


def repository_files(root: Path) -> Iterable[Path]:
    """Walk source files while keeping caches and local evidence private."""
    for directory, names, files in os.walk(str(root), followlinks=False):
        names[:] = sorted(name for name in names if name not in EXCLUDED_DIRECTORIES)
        for name in sorted(files):
            yield Path(directory) / name


def relative_label(root: Path, path: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return str(path)


def strip_code(markdown: str, remove_inline: bool = True) -> str:
    """Mask code without changing line numbers used by diagnostics."""
    result = []
    fence_character = None
    fence_length = 0
    for line in markdown.splitlines(keepends=True):
        match = re.match(r"^[ ]{0,3}(`{3,}|~{3,})", line)
        if fence_character:
            if match and match.group(1)[0] == fence_character and len(match.group(1)) >= fence_length:
                fence_character = None
            result.append("\n" if line.endswith("\n") else "")
        elif match:
            fence_character = match.group(1)[0]
            fence_length = len(match.group(1))
            result.append("\n" if line.endswith("\n") else "")
        else:
            result.append(line)
    text = "".join(result)
    if remove_inline:
        text = re.sub(r"<code\b[^>]*>.*?</code>", "", text, flags=re.IGNORECASE | re.DOTALL)
        text = re.sub(r"(`+)([^\n]*?)\1", "", text)
    return text


def markdown_destinations(markdown: str) -> Iterable[Tuple[int, str]]:
    text = strip_code(markdown)
    patterns = (
        r"!?\[[^\]\n]*\]\(\s*(<[^>\n]+>|(?:[^()\s\\]|\\.|\([^()\n]*\))+)(?:\s+[\"'][^\n]*?[\"'])?\s*\)",
        r"^[ ]{0,3}\[[^\]\n]+\]:\s*(<[^>\n]+>|[^\s]+)",
        r"\b(?:href|src)=[\"']([^\"']+)[\"']",
    )
    for pattern in patterns:
        for match in re.finditer(pattern, text, flags=re.MULTILINE | re.IGNORECASE):
            destination = match.group(1).strip("<>")
            destination = re.sub(r"\\([()\[\] ])", r"\1", destination)
            yield text.count("\n", 0, match.start()) + 1, destination


def local_destination(root: Path, source: Path, destination: str) -> Optional[Tuple[Path, str]]:
    """Resolve repository-local destinations; refuse escapes, including symlinks."""
    parsed = urlsplit(destination)
    if parsed.scheme or parsed.netloc:
        return None
    path_text = unquote(parsed.path).replace("\\", "/")
    if not path_text:
        target = source.resolve()
    elif path_text.startswith("/"):
        target = (root / path_text.lstrip("/")).resolve()
    else:
        target = (source.parent / path_text).resolve()
    try:
        target.relative_to(root.resolve())
    except ValueError as error:
        raise ValueError("link escapes the repository") from error
    return target, unquote(parsed.fragment)


def markdown_anchors(markdown: str) -> Set[str]:
    text = strip_code(markdown, remove_inline=False)
    anchors = set(re.findall(r"\b(?:id|name)=[\"']([^\"']+)[\"']", text, flags=re.IGNORECASE))
    used = {}
    for match in re.finditer(r"^[ ]{0,3}#{1,6}\s+(.+?)\s*#*\s*$", text, flags=re.MULTILINE):
        heading = re.sub(r"<[^>]+>", "", match.group(1)).strip().lower()
        heading = re.sub(r"!?\[([^\]]+)\]\([^)]*\)", r"\1", heading)
        slug = re.sub(r"[^\w\- ]", "", heading).replace(" ", "-")
        suffix = used.get(slug, 0)
        used[slug] = suffix + 1
        anchors.add(slug if not suffix else "{}-{}".format(slug, suffix))
    return anchors


def validate_markdown(root: Path, source: Path, check_anchors: bool = False) -> List[str]:
    errors = []
    markdown = source.read_text(encoding="utf-8-sig")
    for line, destination in markdown_destinations(markdown):
        prefix = "{}:{}: ".format(relative_label(root, source), line)
        try:
            resolved = local_destination(root, source, destination)
        except ValueError as error:
            errors.append(prefix + str(error) + ": " + destination)
            continue
        if resolved is None:
            continue
        target, fragment = resolved
        if not target.exists():
            errors.append(prefix + "missing local link target: " + destination)
        elif check_anchors and fragment and target.is_file() and target.suffix.lower() == ".md":
            if fragment not in markdown_anchors(target.read_text(encoding="utf-8-sig")):
                errors.append(prefix + "missing Markdown anchor: " + destination)
    return errors


def validate_svg(root: Path, source: Path) -> List[str]:
    label = relative_label(root, source)
    try:
        document = ET.parse(str(source)).getroot()
    except (ET.ParseError, OSError) as error:
        return ["{}: malformed SVG: {}".format(label, error)]
    if document.tag != "{http://www.w3.org/2000/svg}svg":
        return [label + ": SVG root must use the standard SVG namespace"]
    errors = []
    for name in ("title", "desc"):
        element = document.find("{http://www.w3.org/2000/svg}" + name)
        if element is None or not "".join(element.itertext()).strip():
            errors.append("{}: SVG needs a nonempty accessible {}".format(label, name))
    labelled_by = document.attrib.get("aria-labelledby", "").split()
    if labelled_by:
        ids = {element.attrib["id"] for element in document.iter() if "id" in element.attrib}
        for identifier in labelled_by:
            if identifier not in ids:
                errors.append("{}: aria-labelledby references missing ID {}".format(label, identifier))
    return errors


def excluded_artifact(path: Path) -> Optional[str]:
    parts = tuple(part.lower() for part in path.parts)
    name = path.name.lower()
    if "pipelines" in parts or (".github" in parts and "workflows" in parts):
        return "pipeline/workflow files are excluded from this lab"
    if re.match(r"azure-pipelines(?:[.-].*)?\.ya?ml$", name):
        return "Azure Pipelines configuration is excluded from this lab"
    if re.search(r"\.tfstate(?:\..*)?$|\.tfplan(?:\..*)?$", name):
        return "state and plan artifacts belong only in ignored local storage"
    if name in {"terraform.tfvars", ".env", "credentials.json"} or name.endswith((".auto.tfvars", ".tfvars.json", ".pfx", ".p12", ".pem", ".key")):
        return "private configuration or key material must not be source-controlled"
    return None


def tracked_paths(root: Path) -> List[Path]:
    """Catch private files force-added despite .gitignore, without reading them."""
    try:
        result = subprocess.run(["git", "-C", str(root), "ls-files", "-z"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    except OSError:
        return []
    if result.returncode:
        return []
    return [Path(os.fsdecode(name)) for name in result.stdout.split(b"\0") if name]


def validate_repository(root: Path, check_anchors: bool = False) -> List[str]:
    root = root.resolve()
    errors = []
    paths = list(repository_files(root))
    source_paths = set()
    for source in paths:
        relative = source.relative_to(root)
        source_paths.add(relative)
        reason = excluded_artifact(relative)
        if reason:
            errors.append("{}: {}".format(relative.as_posix(), reason))
            continue
        try:
            source.resolve().relative_to(root)
        except ValueError:
            errors.append(relative.as_posix() + ": source symlink escapes the repository")
            continue
        if source.suffix.lower() == ".md":
            errors.extend(validate_markdown(root, source, check_anchors))
            text = source.read_text(encoding="utf-8-sig")
            for line_number, line in enumerate(text.splitlines(), 1):
                if re.search(r"\b(?:not|no|never|excluded|without)\b|out.of.scope", line, flags=re.IGNORECASE):
                    continue
                if re.search(r"\b(?:labConfigurationJson|serviceConnectionName|federation_issuer|federation_subject|SYSTEM_ACCESSTOKEN)\b|pipelines/(?:connectivity|workload|destroy-workload)\.ya?ml", line):
                    errors.append("{}:{}: retired pipeline setup reference".format(relative.as_posix(), line_number))
        elif source.suffix.lower() == ".svg":
            errors.extend(validate_svg(root, source))
        if source.suffix.lower() in SOURCE_EXTENSIONS:
            try:
                content = source.read_text(encoding="utf-8-sig")
            except UnicodeDecodeError:
                errors.append(relative.as_posix() + ": text source is not UTF-8")
                continue
            for description, pattern in HIGH_CONFIDENCE_SECRETS:
                if pattern.search(content):
                    # Never reproduce matching credential values in diagnostics.
                    errors.append("{}: possible {}; run the secret scanner before sharing".format(relative.as_posix(), description))
    for relative in tracked_paths(root):
        if relative in source_paths:
            continue
        reason = excluded_artifact(relative)
        if any(part in EXCLUDED_DIRECTORIES for part in relative.parts):
            reason = "ignored local/cached files must not be tracked"
        if reason:
            errors.append("{}: {}".format(relative.as_posix(), reason))
    exercise_directory = root / "wiki" / "exercises"
    exercises = [path for path in exercise_directory.glob("*.md") if re.match(r"^(?:0[1-9]|10)-.+\.md$", path.name)]
    numbers = sorted(path.name[:2] for path in exercises)
    if numbers != ["{:02d}".format(number) for number in range(1, 11)]:
        errors.append("wiki/exercises: expected exactly one numbered Markdown exercise for each of 01 through 10")
    return sorted(set(errors))


def main(arguments: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate without changing files (the default)")
    parser.add_argument("--anchors", action="store_true", help="also check fragments against Markdown headings and explicit IDs")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1], help="repository root; defaults to this tool's repository")
    args = parser.parse_args(arguments)
    if not args.root.is_dir():
        parser.error("repository root is not a directory")
    errors = validate_repository(args.root, check_anchors=args.anchors)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        print("Repository validation failed: {} issue(s).".format(len(errors)), file=sys.stderr)
        return 1
    print("Repository validation passed (local links, SVGs, exercises and source safeguards).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
