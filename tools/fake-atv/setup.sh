#!/usr/bin/env bash
# Sets up the fake Apple TV dev target. Idempotent — safe to re-run.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYATV_DIR="$HERE/.pyatv"
VENV="$HERE/.venv"
PYATV_TAG="v0.18.0"

# pyatv 0.18.0 calls asyncio.get_event_loop() outside a coroutine, which raises
# on Python 3.14. 3.13 is the newest interpreter that works.
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3.13 || true)}"
if [ -z "$PYTHON_BIN" ]; then
	echo "python3.13 not found — set PYTHON_BIN to a 3.9–3.13 interpreter" >&2
	exit 1
fi

if [ ! -d "$PYATV_DIR" ]; then
	echo "==> cloning pyatv $PYATV_TAG (tests.fake_device is not in the wheel)"
	git clone --quiet --depth 50 --branch "$PYATV_TAG" \
		https://github.com/postlund/pyatv "$PYATV_DIR"
fi

if [ ! -d "$VENV" ]; then
	echo "==> creating venv with $($PYTHON_BIN -V)"
	"$PYTHON_BIN" -m venv "$VENV"
	"$VENV/bin/pip" install --quiet --upgrade pip
fi

echo "==> installing pyatv and its test dependencies"
"$VENV/bin/pip" install --quiet \
	-r "$PYATV_DIR/requirements/requirements.txt" \
	-r "$PYATV_DIR/requirements/requirements_test.txt"
"$VENV/bin/pip" install --quiet -e "$PYATV_DIR"

echo "==> ready — start it with tools/fake-atv/run.sh"
