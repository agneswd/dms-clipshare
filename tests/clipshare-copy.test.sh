#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
script="${root_dir}/scripts/clipshare-copy"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin" "$tmp_dir/recordings"

cat > "$tmp_dir/bin/dms" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${FAKE_DMS_ARGS:?}"
cat > "${FAKE_DMS_STDIN:?}"
if [ "${FAKE_DMS_FAIL:-0}" = "1" ]; then
    printf 'dms clipboard copy failed\n' >&2
    exit 1
fi
EOF

cat > "$tmp_dir/bin/wl-copy" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${FAKE_WL_ARGS:?}"
cat > "${FAKE_WL_STDIN:?}"
if [ "${FAKE_WL_FAIL:-0}" = "1" ]; then
    printf 'wl-copy failed\n' >&2
    exit 1
fi
EOF

chmod +x "$tmp_dir/bin/dms" "$tmp_dir/bin/wl-copy"

run_copy() {
    DMS_BIN="$tmp_dir/bin/dms" \
    WL_COPY_BIN="$tmp_dir/bin/wl-copy" \
    FAKE_DMS_ARGS="$tmp_dir/dms.args" \
    FAKE_DMS_STDIN="$tmp_dir/dms.stdin" \
    FAKE_WL_ARGS="$tmp_dir/wl.args" \
    FAKE_WL_STDIN="$tmp_dir/wl.stdin" \
    "$@"
}

assert_contains() {
    [[ "$1" == *"$2"* ]] || { printf 'Expected %q in %q\n' "$2" "$1" >&2; exit 1; }
}

video_path="$tmp_dir/recordings/record_123.mp4"
printf 'video-bytes-should-not-be-copied' > "$video_path"

run_copy "$script" copy-file "$video_path"
grep -Fxq 'clipboard copy -t text/uri-list' "$tmp_dir/dms.args"
printf 'file://%s\r\n' "$video_path" > "$tmp_dir/expected.uri"
cmp -s "$tmp_dir/dms.stdin" "$tmp_dir/expected.uri"
[[ ! -e "$tmp_dir/wl.args" ]]

space_path="$tmp_dir/recordings/record 456.mp4"
printf 'spaced' > "$space_path"
run_copy "$script" copy-file "$space_path"
printf 'file://%s/recordings/record%%20456.mp4\r\n' "$tmp_dir" > "$tmp_dir/expected.space.uri"
cmp -s "$tmp_dir/dms.stdin" "$tmp_dir/expected.space.uri"

FAKE_DMS_FAIL=1 run_copy "$script" copy-file "$video_path"
grep -Fxq -- '-t text/uri-list' "$tmp_dir/wl.args"
cmp -s "$tmp_dir/wl.stdin" "$tmp_dir/expected.uri"

run_copy "$script" copy-text "https://files.catbox.moe/video.mp4"
grep -Fxq 'clipboard copy -t text/plain;charset=utf-8' "$tmp_dir/dms.args"
printf 'https://files.catbox.moe/video.mp4' > "$tmp_dir/expected.text"
cmp -s "$tmp_dir/dms.stdin" "$tmp_dir/expected.text"

set +e
missing_error="$(run_copy "$script" copy-file "$tmp_dir/recordings/missing.mp4" 2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]]
assert_contains "$missing_error" "missing"

set +e
relative_error="$(run_copy "$script" copy-file "relative.mp4" 2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]]
assert_contains "$relative_error" "absolute"

empty_path="$tmp_dir/recordings/empty.mp4"
: > "$empty_path"
set +e
empty_error="$(run_copy "$script" copy-file "$empty_path" 2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]]
assert_contains "$empty_error" "empty"

set +e
both_fail="$(FAKE_DMS_FAIL=1 FAKE_WL_FAIL=1 run_copy "$script" copy-file "$video_path" 2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]]
assert_contains "$both_fail" "dms clipboard copy failed"

printf 'clipshare-copy tests passed\n'
