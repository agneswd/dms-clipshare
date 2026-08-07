#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
script="${root_dir}/scripts/clipshare-record"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin" "$tmp_dir/runtime" "$tmp_dir/recordings"

cat > "$tmp_dir/bin/slurp" <<'EOF'
#!/usr/bin/env bash
printf '100x100+0+0\n'
EOF

cat > "$tmp_dir/bin/slurp-empty" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$tmp_dir/bin/pactl" <<'EOF'
#!/usr/bin/env bash
printf 'TestSink\n'
EOF

cat > "$tmp_dir/bin/gpu-screen-recorder" <<'EOF'
#!/usr/bin/env bash
output=""
while [ "$#" -gt 0 ]; do
    if [ "$1" = "-o" ]; then
        output="$2"
        shift 2
    else
        shift
    fi
done
printf 'fake video\n' > "$output"
exec sleep 3600
EOF

cat > "$tmp_dir/bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
input=""
output=""
while [ "$#" -gt 0 ]; do
    if [ "$1" = "-i" ]; then
        input="$2"
        shift 2
    elif [[ "$1" = *.mp4 ]]; then
        output="$1"
        shift
    else
        shift
    fi
done
cp -- "$input" "$output"
EOF

cat > "$tmp_dir/bin/ffmpeg-fail" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF

chmod +x "$tmp_dir/bin"/*

run() {
    CLIPSHARE_RUNTIME_DIR="$tmp_dir/runtime" \
    CLIPSHARE_RECORD_DIR="$tmp_dir/recordings" \
    GSR_BIN="$tmp_dir/bin/gpu-screen-recorder" \
    SLURP_BIN="$tmp_dir/bin/slurp" \
    PACTL_BIN="$tmp_dir/bin/pactl" \
    FFMPEG_BIN="${1:-$tmp_dir/bin/ffmpeg}" \
    CLIPSHARE_STOP_SIGNAL=TERM \
    "$script" toggle
}

assert_contains() {
    [[ "$1" == *"$2"* ]] || { printf 'Expected %q in %q\n' "$2" "$1" >&2; exit 1; }
}

started="$(run)"
assert_contains "$started" "started"
state_file="$tmp_dir/runtime/recording.state"
[[ -s "$state_file" ]]
IFS=$'\t' read -r _ _ mkv_path < "$state_file"
[[ -s "$mkv_path" ]]

ready="$(run)"
assert_contains "$ready" "ready"
IFS=$'\t' read -r event mp4_path mp4_size <<< "$ready"
[[ "$event" = "ready" ]]
[[ -s "$mp4_path" ]]
[[ "$mp4_size" = "$(stat -c %s "$mp4_path")" ]]
[[ ! -e "$mkv_path" ]]
[[ ! -e "$state_file" ]]

discarded="$(CLIPSHARE_RECORD_DIR="$tmp_dir/recordings" "$script" discard "$mp4_path")"
assert_contains "$discarded" "discarded"
[[ ! -e "$mp4_path" ]]

outside_path="$tmp_dir/outside.mp4"
printf 'outside recording\n' > "$outside_path"
set +e
refused="$(CLIPSHARE_RECORD_DIR="$tmp_dir/recordings" "$script" discard "$outside_path" 2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]]
assert_contains "$refused" "error"
[[ -s "$outside_path" ]]

cancelled="$(CLIPSHARE_RUNTIME_DIR="$tmp_dir/runtime" CLIPSHARE_RECORD_DIR="$tmp_dir/recordings" SLURP_BIN="$tmp_dir/bin/slurp-empty" "$script" toggle)"
assert_contains "$cancelled" "cancelled"

printf '999999\t0\t%s\n' "$tmp_dir/recordings/stale.mkv" > "$state_file"
stale_recovered="$(run)"
assert_contains "$stale_recovered" "started"
run >/dev/null

run >/dev/null
set +e
failed="$(run "$tmp_dir/bin/ffmpeg-fail" 2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]]
assert_contains "$failed" "error"
failed_mkv="$(find "$tmp_dir/recordings" -name '*.mkv' -type f -print -quit)"
[[ -n "$failed_mkv" && -s "$failed_mkv" ]]

printf 'clipshare-record tests passed\n'
