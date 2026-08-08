#!/usr/bin/env bash
# Starts the fake Apple TV. Extra args are passed to atv_fake.py.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$HERE/.venv"

if [ ! -x "$VENV/bin/python" ]; then
	echo "not set up yet — run tools/fake-atv/setup.sh first" >&2
	exit 1
fi

# Run from the pyatv checkout so `tests.fake_device` resolves.
cd "$HERE/.pyatv"
exec "$VENV/bin/python" "$HERE/atv_fake.py" "$@"
