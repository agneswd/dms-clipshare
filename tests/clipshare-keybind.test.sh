#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

cat > "$tmp_dir/dms" <<'EOF'
#!/usr/bin/env bash
if [ "$1 $2" = "keybinds show" ]; then
    printf '%s\n' "${FAKE_BINDS:?}"
else
    printf '%s\n' "$*" > "${FAKE_SET_LOG:?}"
fi
EOF
chmod +x "$tmp_dir/dms"

action="spawn dms ipc call clipShare toggle"
binds="{\"binds\":{\"System\":[{\"key\":\"Shift+Print\",\"action\":\"$action\"}]}}"
DMS_BIN="$tmp_dir/dms" FAKE_BINDS="$binds" FAKE_SET_LOG="$tmp_dir/set.log" \
    "$root_dir/scripts/clipshare-keybind" "Mod+Print"
grep -Fq 'keybinds set niri Mod+Print' "$tmp_dir/set.log"
grep -Fq -- '--replace-key Shift+Print' "$tmp_dir/set.log"

DMS_BIN="$tmp_dir/dms" FAKE_BINDS="$binds" FAKE_SET_LOG="$tmp_dir/hyprland-set.log" \
    "$root_dir/scripts/clipshare-keybind" "SUPER+Print" hyprland
grep -Fq 'keybinds set hyprland SUPER+Print' "$tmp_dir/hyprland-set.log"

DMS_BIN="$tmp_dir/dms" FAKE_BINDS="$binds" FAKE_SET_LOG="$tmp_dir/mangowc-set.log" \
    "$root_dir/scripts/clipshare-keybind" "SUPER+Print" mangowc
grep -Fq 'keybinds set mangowc SUPER+Print' "$tmp_dir/mangowc-set.log"

conflict_binds='{"binds":{"System":[{"key":"Shift+Print","action":"spawn dms ipc call clipShare toggle"},{"key":"Mod+Print","action":"spawn other"}]}}'
set +e
error="$(DMS_BIN="$tmp_dir/dms" FAKE_BINDS="$conflict_binds" FAKE_SET_LOG="$tmp_dir/set.log" \
    "$root_dir/scripts/clipshare-keybind" "Mod+Print" 2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]]
[[ "$error" == *"Shortcut is already in use"* ]]

printf 'clipshare-keybind tests passed\n'
