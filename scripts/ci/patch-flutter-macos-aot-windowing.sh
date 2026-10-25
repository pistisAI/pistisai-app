#!/usr/bin/env bash
# Work around Flutter 3.47 macOS release AOT gen_snapshot crash on experimental
# windowing FFI structs (flutter/flutter#188060, flutter/flutter#191575).
set -euo pipefail

WINDOW_FILE="${FLUTTER_ROOT:?}/packages/flutter/lib/src/widgets/_window_macos.dart"

if [[ ! -f "$WINDOW_FILE" ]]; then
  echo "Expected Flutter windowing file not found: $WINDOW_FILE" >&2
  exit 1
fi

if grep -q "vm:entry-point" "$WINDOW_FILE"; then
  echo "Flutter macOS windowing AOT patch already applied"
  exit 0
fi

python3 <<'PY'
import os
import re
from pathlib import Path

path = Path(os.environ["FLUTTER_ROOT"]) / "packages/flutter/lib/src/widgets/_window_macos.dart"
text = path.read_text()
for class_name in (
    "_WindowCreationRequest",
    "_Size",
    "_Offset",
    "_Rect",
    "_Constraints",
):
    pattern = rf"^final class {re.escape(class_name)} "
    replacement = f"@pragma('vm:entry-point')\nfinal class {class_name} "
    text, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f"Failed to patch {class_name} in {path}")

path.write_text(text)
print(f"Applied Flutter macOS windowing AOT patch to {path}")
PY
