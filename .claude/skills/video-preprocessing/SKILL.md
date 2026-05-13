---
name: video-preprocessing
description: >
  Extract dan analisis frames dari video screen recording untuk bug diagnosis.
  Digunakan saat user submit video (.mp4, .webm, .mov) bersama bug report.
  Orchestrator membaca skill ini HANYA saat input mengandung video file.
---

# Video Preprocessing

## KAPAN SKILL INI DIBACA
- Saat user input mengandung file video (.mp4, .mov, .webm, .avi, .mkv)
- Saat user mention "recording", "screen recording", "video"
- JANGAN baca untuk input non-video

## PREREQUISITES
- ffmpeg dan ffprobe harus tersedia
- Verify: `which ffmpeg && which ffprobe`

---

## Step 1: Verify ffmpeg
```bash
command -v ffmpeg &>/dev/null && echo "FFMPEG_OK" || echo "FFMPEG_MISSING"
```

**Jika FFMPEG_MISSING:**
```
ffmpeg tidak terinstall. Video tidak bisa diproses.
Install sesuai OS:
  Ubuntu/Debian/WSL : sudo apt install -y ffmpeg
  macOS             : brew install ffmpeg
  Windows           : winget install --id Gyan.FFmpeg
```
→ Lanjut pipeline TANPA video context. Inform user.

## Step 2: Check Existing Frames (Resume Support)

Sebelum extract, cek apakah frames dari session sebelumnya sudah ada:

```bash
EXISTING_FRAMES=$(find docs/video-frames -name "frame_*.jpg" 2>/dev/null | head -1)
WAVE_STATE="docs/wave-execution-state.md"

if [ -n "$EXISTING_FRAMES" ] && [ -f "$WAVE_STATE" ]; then
  EXISTING_DIR=$(dirname "$EXISTING_FRAMES")
  EXISTING_COUNT=$(ls "${EXISTING_DIR}"/frame_*.jpg 2>/dev/null | wc -l)
  echo "Reusing existing video frames from previous session: $EXISTING_DIR ($EXISTING_COUNT frames)"
  FRAME_DIR="$EXISTING_DIR"
  FRAME_COUNT="$EXISTING_COUNT"
  # SKIP extraction — langsung ke Step 4
fi
```

Jika frames sudah ada DAN wave-execution-state.md ada → SKIP extraction, re-use existing frames. Log: "Reusing existing video frames from previous session"

## Step 3: Extract Frames

**Hanya jika Step 2 tidak menemukan existing frames.**

Orchestrator BOLEH jalankan ffmpeg langsung — ini preprocessing input, bukan application code editing.

```bash
VIDEO_FILE="[path dari /start]"

# Detect duration
DURATION_RAW=$(ffmpeg -i "$VIDEO_FILE" 2>&1 | grep "Duration" | head -1 | sed 's/.*Duration: //' | sed 's/,.*//')
HOURS=$(echo "$DURATION_RAW" | cut -d: -f1)
MINUTES=$(echo "$DURATION_RAW" | cut -d: -f2)
SECONDS=$(echo "$DURATION_RAW" | cut -d: -f3 | cut -d. -f1)
TOTAL_SECONDS=$(( ${HOURS#0} * 3600 + ${MINUTES#0} * 60 + ${SECONDS#0} ))

# Smart sampling interval
if [ "$TOTAL_SECONDS" -le 15 ]; then INTERVAL=1
elif [ "$TOTAL_SECONDS" -le 60 ]; then INTERVAL=2
elif [ "$TOTAL_SECONDS" -le 180 ]; then INTERVAL=3
else INTERVAL=5; fi

# Cap at 20 frames (default — adjusted per scope setelah classification)
MAX_FRAMES=20
ESTIMATED=$(( TOTAL_SECONDS / INTERVAL ))
[ "$ESTIMATED" -gt "$MAX_FRAMES" ] && INTERVAL=$(( TOTAL_SECONDS / MAX_FRAMES ))

# Extract
FRAME_ID="vid-$(date +%s)"
FRAME_DIR="docs/video-frames/${FRAME_ID}"
mkdir -p "$FRAME_DIR"

ffmpeg -i "$VIDEO_FILE" \
  -vf "fps=1/${INTERVAL},scale='min(1280,iw)':-2" \
  -q:v 3 \
  -frames:v $MAX_FRAMES \
  "${FRAME_DIR}/frame_%04d.jpg" \
  2>/dev/null

FRAME_COUNT=$(ls "${FRAME_DIR}"/frame_*.jpg 2>/dev/null | wc -l)
echo "Video frames extracted: $FRAME_COUNT frames → $FRAME_DIR"
```

## Step 4: Generate Frame Index
```bash
cat > "${FRAME_DIR}/index.md" << INDEXEOF
# Video Frame Index
- **Source:** ${VIDEO_FILE}
- **Duration:** ${DURATION_RAW}
- **Frames extracted:** ${FRAME_COUNT}
- **Sampling interval:** ${INTERVAL} detik

## Frame Sequence
| Frame | Timestamp | File |
|-------|-----------|------|
$(ls "${FRAME_DIR}"/frame_*.jpg | sort | while read -r f; do
  NUM=$(basename "$f" | sed 's/frame_//;s/\.jpg//')
  TIMESTAMP=$(( ${NUM#0} * INTERVAL ))
  printf "| %d | %d:%02d | %s |\n" "${NUM#0}" $((TIMESTAMP/60)) $((TIMESTAMP%60)) "$(basename $f)"
done)

## Cara Membaca
Baca frame secara BERURUTAN dari frame 1 ke frame terakhir.
Perhatikan PERUBAHAN antar frame — ini menunjukkan interaksi user atau state change.
INDEXEOF
```

## Step 5: Distribute ke Agent yang Relevan

Setelah frames di-extract, simpan path di pipeline-state.md:
```bash
echo "video_frames : $FRAME_DIR" >> docs/pipeline-state.md
echo "video_source : $VIDEO_FILE" >> docs/pipeline-state.md
echo "video_max_frames : 20" >> docs/pipeline-state.md
```

**Setelah scope classification** (di Phase 0 atau setelah Scope Detection), adjust frame limit berdasarkan scope:

```bash
# Context-aware frame limit — adjust berdasarkan scope type
case "$SCOPE_TYPE" in
  SMALL_EDIT)           VIDEO_MAX_FRAMES=10 ;;
  BUG_FIX|BUG\ FIX)    VIDEO_MAX_FRAMES=25 ;;
  NEW_FEATURE|NEW\ FEATURE) VIDEO_MAX_FRAMES=15 ;;
  GREENFIELD)           VIDEO_MAX_FRAMES=10 ;;
  DISCUSSION)           VIDEO_MAX_FRAMES=25 ;;
  *)                    VIDEO_MAX_FRAMES=20 ;;
esac

# Update pipeline-state.md dengan limit final
sed -i "s/^video_max_frames :.*/video_max_frames : $VIDEO_MAX_FRAMES/" docs/pipeline-state.md
echo "Video frame limit adjusted to $VIDEO_MAX_FRAMES for scope $SCOPE_TYPE"
```

Jika frames sudah di-extract dengan jumlah lebih banyak dari limit scope → agent hanya membaca evenly distributed N frames dari total set. Orchestrator include instruksi ini di ACP.

Agent yang menerima video context (via ACP / agent-context.md):
- **design-director** — referensi desain dari video (layout, colors, flow)
- **fe-developer** — referensi UI implementation dari video
- **tracer** — visual bug analysis dari screen recording
- **fix-strategist** — visual bug context untuk fix strategy
- **brief-interpreter** — interpret video sebagai brief visual

Instruksi untuk agent: "Baca frames berurutan di `$FRAME_DIR` menggunakan Read tool. Lihat `$FRAME_DIR/index.md` untuk timestamp mapping. Maksimal baca `video_max_frames` frame (cek docs/pipeline-state.md). WAJIB sebut timestamp saat merujuk frame."

## Step 6: Cleanup (dengan Safety Check)

Frames HANYA dibersihkan jika pipeline benar-benar selesai.

```bash
# Safety check sebelum cleanup
WAVE_STATE="docs/wave-execution-state.md"
INCOMPLETE=$(grep -c '\[ \]' "$WAVE_STATE" 2>/dev/null || echo "0")

if [ "$INCOMPLETE" -gt 0 ]; then
  echo "SKIP video cleanup: pipeline masih ada $INCOMPLETE incomplete tasks"
else
  rm -rf docs/video-frames/
  echo "Video frames cleaned up"
fi
```

**Aturan cleanup:**
- Pipeline selesai SUKSES (semua `[x]`) → hapus frames
- `/clean` command → hapus frames (user eksplisit minta exit)
- `/start resume` → JANGAN hapus, re-use existing frames
- Pipeline ongoing (ada `[ ]`) → JANGAN hapus
