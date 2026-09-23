#!/bin/sh
# Builds dist/HyperPatch.zip.
#
# This is the single source of truth for what ships inside the module. Both
# .github/workflows/build.yml (smoke test on push) and release.yml (publish on
# tag) call this script, so they cannot drift apart about the file list - a
# smoke test that disagrees with the release is worse than no smoke test,
# because it passes while the release is wrong.
#
# The exclusion list is a denylist on purpose: if you add a file to the repo
# that must NOT ship, add it here once and both workflows are correct.

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p dist
rm -f dist/HyperPatch.zip

zip -r -X dist/HyperPatch.zip . \
    -x '.git/*' \
       '.github/*' \
       'dist/*' \
       'tools/*' \
       'update.json' \
       'CHANGELOG.md' \
       '.gitattributes' \
       '.gitignore'

unzip -l dist/HyperPatch.zip

# A module ZIP is only installable if module.prop sits at its root.
unzip -l dist/HyperPatch.zip | grep -q ' module\.prop$'
