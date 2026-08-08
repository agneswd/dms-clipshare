#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
script="${root_dir}/scripts/clipshare-process"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin" "$tmp_dir/runtime"

cat > "$tmp_dir/bin/ffprobe" <<'EOF'
#!/usr/bin/env bash
if [ "${FAKE_PROBE_FAIL:-0}" = "1" ]; then
    exit 1
fi
case "$*" in
    *format=duration*) printf '%s\n' "${FAKE_DURATION:-60}" ;;
    *stream=codec_name*) printf 'av1\n' ;;
    *stream=width,height*) printf '1280x720\n' ;;
esac
EOF

cat > "$tmp_dir/bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FAKE_ARGS_LOG:?}"
pass=""
output=""
codec=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -pass) pass="$2"; shift 2 ;;
        -c:v) codec="$2"; shift 2 ;;
        *.mp4|*.jpg) output="$1"; shift ;;
        *) shift ;;
    esac
done
[ "${FAKE_FFMPEG_FAIL_PASS:-0}" != "$pass" ] || exit 1
if [ "$pass" = "2" ] || [ "$codec" = "av1_vaapi" ]; then
    printf 'out_time_us=30000000\n'
    printf 'out_time_us=60000000\n'
    truncate -s "${FAKE_OUTPUT_SIZE:-8000}" "$output"
elif [[ "$output" = *.jpg ]]; then
    truncate -s 1000 "$output"
fi
EOF

cat > "$tmp_dir/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FAKE_CURL_LOG:?}"
[ "${FAKE_CURL_FAIL:-0}" != "1" ] || exit 22
case "$*" in
    *thumbnail.jpg*) printf 'https://files.catbox.moe/preview.jpg\n' ;;
    *) printf 'https://files.catbox.moe/video.mp4\n' ;;
esac
EOF

chmod +x "$tmp_dir/bin/ffmpeg" "$tmp_dir/bin/ffprobe" "$tmp_dir/bin/curl"

run_process() {
    CLIPSHARE_RUNTIME_DIR="$tmp_dir/runtime" \
    CLIPSHARE_LOCAL_LIMIT_BYTES=10000 \
    CLIPSHARE_LOCAL_TARGET_BYTES=9000 \
    FFMPEG_BIN="$tmp_dir/bin/ffmpeg" \
    FFPROBE_BIN="$tmp_dir/bin/ffprobe" \
    FAKE_ARGS_LOG="$tmp_dir/ffmpeg-args" \
    CLIPSHARE_VAAPI_DEVICE="${CLIPSHARE_VAAPI_DEVICE:-/dev/dri/renderD128}" \
    "$script" local-compress "$1" "${2:-balanced}"
}

run_share() {
    CLIPSHARE_RUNTIME_DIR="$tmp_dir/runtime" \
    CLIPSHARE_SHARE_LIMIT_BYTES="${SHARE_LIMIT_BYTES:-10000}" \
    CLIPSHARE_SHARE_TARGET_BYTES=9000 \
    FFMPEG_BIN="$tmp_dir/bin/ffmpeg" \
    FFPROBE_BIN="$tmp_dir/bin/ffprobe" \
    CURL_BIN="$tmp_dir/bin/curl" \
    FAKE_ARGS_LOG="$tmp_dir/ffmpeg-args" \
    FAKE_CURL_LOG="$tmp_dir/curl-args" \
    "$script" share "$1"
}

assert_contains() {
    [[ "$1" == *"$2"* ]] || { printf 'Expected %q in %q\n' "$2" "$1" >&2; exit 1; }
}

original="$tmp_dir/recording.mp4"
printf 'original recording\n' > "$original"
success="$(run_process "$original")"
assert_contains "$success" $'stage\tchecking'
assert_contains "$success" $'stage\tcompressing'
assert_contains "$success" $'progress\t50'
assert_contains "$success" $'progress\t100'
assert_contains "$success" $'compressed\t'
compact="${original%.mp4}_small.mp4"
compressed_line="${success##*$'\n'}"
IFS=$'\t' read -r event compressed_path compressed_size <<< "$compressed_line"
[[ "$event" = "compressed" ]]
[[ "$compressed_path" = "$compact" ]]
[[ ! -e "$original" ]]
[[ -s "$compact" ]]
[[ "$(stat -c %s "$compact")" -lt 10000 ]]
[[ "$compressed_size" = "$(stat -c %s "$compact")" ]]
assert_contains "$(cat "$tmp_dir/ffmpeg-args")" "-preset 6"

best_original="$tmp_dir/best.mp4"
printf 'best quality\n' > "$best_original"
run_process "$best_original" best >/dev/null
assert_contains "$(tail -2 "$tmp_dir/ffmpeg-args")" "-preset 4"

gpu_original="$tmp_dir/gpu.mp4"
printf 'fast gpu\n' > "$gpu_original"
gpu_success="$(run_process "$gpu_original" gpu)"
assert_contains "$gpu_success" $'compressed\t'
assert_contains "$(tail -1 "$tmp_dir/ffmpeg-args")" "-c:v av1_vaapi"

failed_original="$tmp_dir/failed.mp4"
printf 'keep me\n' > "$failed_original"
set +e
failed="$(FAKE_FFMPEG_FAIL_PASS=2 run_process "$failed_original" 2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]]
assert_contains "$failed" $'error\tCompression failed'
[[ -s "$failed_original" ]]
[[ ! -e "${failed_original%.mp4}_small.mp4" ]]

oversize_original="$tmp_dir/oversize.mp4"
printf 'keep me too\n' > "$oversize_original"
set +e
oversize="$(FAKE_OUTPUT_SIZE=10000 run_process "$oversize_original" 2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]]
assert_contains "$oversize" $'error\tCompressed recording is not below 10 MB'
[[ -s "$oversize_original" ]]
[[ ! -e "${oversize_original%.mp4}_small.mp4" ]]

invalid_original="$tmp_dir/invalid.mp4"
printf 'keep me three\n' > "$invalid_original"
set +e
invalid="$(FAKE_PROBE_FAIL=1 run_process "$invalid_original" 2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]]
assert_contains "$invalid" $'error\tCould not read recording duration'
[[ -s "$invalid_original" ]]

share_original="$tmp_dir/share.mp4"
printf 'public recording\n' > "$share_original"
share_success="$(SHARE_LIMIT_BYTES=100000 run_share "$share_original")"
assert_contains "$share_success" $'stage\tpreview'
assert_contains "$share_success" $'stage\tuploading-video'
assert_contains "$share_success" $'stage\tuploading-preview'
assert_contains "$share_success" $'result\thttps://files.catbox.moe/video.mp4\thttps://files.catbox.moe/preview.jpg\t1280\t720'
[[ -s "$share_original" ]]

large_share="$tmp_dir/large-share.mp4"
truncate -s 10000 "$large_share"
large_success="$(run_share "$large_share")"
assert_contains "$large_success" $'stage\tcompressing'
assert_contains "$large_success" $'progress\t100'
assert_contains "$large_success" $'result\t'
[[ -s "$large_share" ]]

failed_share="$tmp_dir/failed-share.mp4"
printf 'keep public original\n' > "$failed_share"
set +e
failed_upload="$(FAKE_CURL_FAIL=1 SHARE_LIMIT_BYTES=100000 run_share "$failed_share" 2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]]
assert_contains "$failed_upload" $'error\tCatbox video upload failed'
[[ -s "$failed_share" ]]

printf 'clipshare-process tests passed\n'
