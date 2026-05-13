---
name: video-input
description: >
  Extract frames dari video (.mp4, .mov, .webm, .avi, .mkv) menggunakan ffmpeg.
  Smart sampling berdasarkan durasi video. Output: ordered image sequence
  di docs/video-frames/{id}/ — ready untuk visual analysis oleh agent.
allowed-tools: Bash, Read, Write
---

# Video Input → Frame Extraction

Converts video files to ordered image sequences for visual analysis by agents.
Claude Code tidak bisa menerima video secara native — skill ini extract frames
sebagai visual context.

## When to Use
- User mengirim screen recording flow aplikasi sebagai referensi desain
- User mengirim recording bug untuk diagnosis
- Video sebagai attachment yang melengkapi task lain
- Agent perlu memahami visual flow atau UI dari video

## Supported Formats
- `.mp4` (H.264/H.265)
- `.mov` (QuickTime)
- `.webm` (VP8/VP9)
- `.avi` (berbagai codec)
- `.mkv` (Matroska)

Format support tergantung pada codec yang terinstall di ffmpeg.

## Process

### Step 1: Verify ffmpeg

```bash
command -v ffmpeg &>/dev/null && echo "FFMPEG_OK" || echo "FFMPEG_MISSING"
```

**Jika FFMPEG_MISSING:**
```
ffmpeg tidak terinstall. Install sesuai OS:
  Ubuntu/Debian/WSL : sudo apt install -y ffmpeg
  macOS             : brew install ffmpeg
  RedHat/Fedora     : sudo dnf install -y ffmpeg
  Arch              : sudo pacman -S --noconfirm ffmpeg
  Windows (winget)  : winget install --id Gyan.FFmpeg
  Windows (choco)   : choco install ffmpeg -y
```
→ STOP. Tidak bisa proses video tanpa ffmpeg.

### Step 2: Validate Video File

```bash
VIDEO_FILE="INPUT_FILE"

# Check file exists
if [ ! -f "$VIDEO_FILE" ]; then
  echo "ERROR: File not found: $VIDEO_FILE"
  exit 1
fi

# Check extension
EXT=$(echo "$VIDEO_FILE" | grep -oE '\.[^.]+$' | tr '[:upper:]' '[:lower:]')
case "$EXT" in
  .mp4|.mov|.webm|.avi|.mkv) echo "FORMAT_OK: $EXT" ;;
  *) echo "FORMAT_UNSUPPORTED: $EXT — supported: .mp4, .mov, .webm, .avi, .mkv"; exit 1 ;;
esac

# Probe video info
ffmpeg -i "$VIDEO_FILE" 2>&1 | grep -E "Duration|Stream.*Video"
```

### Step 3: Detect Duration & Calculate Sampling

```bash
# Extract duration in seconds
DURATION_RAW=$(ffmpeg -i "$VIDEO_FILE" 2>&1 | grep "Duration" | head -1 | sed 's/.*Duration: //' | sed 's/,.*//')
HOURS=$(echo "$DURATION_RAW" | cut -d: -f1)
MINUTES=$(echo "$DURATION_RAW" | cut -d: -f2)
SECONDS=$(echo "$DURATION_RAW" | cut -d: -f3 | cut -d. -f1)
TOTAL_SECONDS=$(( ${HOURS#0} * 3600 + ${MINUTES#0} * 60 + ${SECONDS#0} ))

echo "Duration: ${DURATION_RAW} (${TOTAL_SECONDS}s)"

# Video terlalu panjang warning
if [ "$TOTAL_SECONDS" -gt 300 ]; then
  echo "WARNING: Video > 5 menit ($TOTAL_SECONDS detik). Hanya sample frames yang akan diambil."
fi

# Smart sampling interval
if [ "$TOTAL_SECONDS" -le 15 ]; then
  INTERVAL=1       # Video pendek: setiap 1 detik
elif [ "$TOTAL_SECONDS" -le 60 ]; then
  INTERVAL=2       # Video sedang: setiap 2 detik
elif [ "$TOTAL_SECONDS" -le 180 ]; then
  INTERVAL=3       # Video 1-3 menit: setiap 3 detik
else
  INTERVAL=5       # Video panjang: setiap 5 detik
fi

# Cap frame count (default 20 — adjusted per scope via orchestrator)
MAX_FRAMES=${VIDEO_MAX_FRAMES:-20}
ESTIMATED_FRAMES=$(( TOTAL_SECONDS / INTERVAL ))
if [ "$ESTIMATED_FRAMES" -gt "$MAX_FRAMES" ]; then
  INTERVAL=$(( TOTAL_SECONDS / MAX_FRAMES ))
  [ "$INTERVAL" -lt 1 ] && INTERVAL=1
fi

echo "Sampling: 1 frame setiap ${INTERVAL} detik (est. $((TOTAL_SECONDS / INTERVAL)) frames, max $MAX_FRAMES)"
```

### Step 4: Extract Frames

```bash
# Create output directory
FRAME_ID="vid-$(date +%s)"
FRAME_DIR="docs/video-frames/${FRAME_ID}"
mkdir -p "$FRAME_DIR"

# Extract frames — JPEG format, max 1280px width
ffmpeg -i "$VIDEO_FILE" \
  -vf "fps=1/${INTERVAL},scale='min(1280,iw)':-2" \
  -q:v 3 \
  -frames:v $MAX_FRAMES \
  "${FRAME_DIR}/frame_%04d.jpg" \
  2>/dev/null

FRAME_COUNT=$(ls "${FRAME_DIR}"/frame_*.jpg 2>/dev/null | wc -l)
echo "Extracted: $FRAME_COUNT frames → $FRAME_DIR"
```

### Step 5: Generate Frame Index

Buat index file untuk agent yang akan membaca frames:

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
Setiap frame merepresentasikan snapshot layar pada timestamp tersebut.
Perhatikan PERUBAHAN antar frame — ini menunjukkan interaksi user atau state change.
Jika menganalisis bug: fokus pada frame dimana behavior berubah dari expected ke unexpected.
Jika menganalisis desain/flow: perhatikan urutan screen, navigasi, dan transisi.
INDEXEOF

echo "Frame index: ${FRAME_DIR}/index.md"
```

### Step 6: Present Frames to Agent

Agent yang menerima video context harus:

1. Baca `${FRAME_DIR}/index.md` untuk metadata dan frame list
2. Baca frames secara berurutan menggunakan Read tool (Claude bisa baca image files)
3. Analisis visual sequence: perubahan UI, flow navigasi, error yang muncul, dll
4. **WAJIB menyebut timestamp** saat merujuk ke frame dalam analisis:
   - Contoh BENAR: "Pada 0:12, terlihat form submit button di-click tapi response tidak muncul"
   - Contoh BENAR: "Di 0:03 layout masih normal, tapi pada 0:06 sidebar hilang"
   - Contoh SALAH: "Di salah satu frame terlihat error" (tanpa timestamp)

```bash
# Contoh: baca 5 frame pertama untuk quick overview
for f in $(ls "${FRAME_DIR}"/frame_*.jpg | head -5); do
  echo "Reading: $f"
  # Agent uses Read tool on each image file
done
```

**Tips untuk agent:**
- Untuk referensi desain: fokus pada layout, color, typography, component structure
- Untuk bug recording: cari frame di mana error/anomali muncul, compare sebelum/sesudah
- Untuk flow analysis: perhatikan transisi antar screen, navigation pattern
- **Selalu narasikan perubahan antar-frame:** "Dari 0:03 ke 0:06, user berpindah dari halaman A ke B"

## Re-use Protocol (Resume Support)

Sebelum extract frames, cek apakah frames dari session sebelumnya sudah ada:

```bash
EXISTING_FRAMES=$(find docs/video-frames -name "frame_*.jpg" 2>/dev/null | head -1)
WAVE_STATE="docs/wave-execution-state.md"

if [ -n "$EXISTING_FRAMES" ] && [ -f "$WAVE_STATE" ]; then
  EXISTING_DIR=$(dirname "$EXISTING_FRAMES")
  EXISTING_COUNT=$(ls "${EXISTING_DIR}"/frame_*.jpg 2>/dev/null | wc -l)
  echo "Reusing existing video frames from previous session: $EXISTING_DIR ($EXISTING_COUNT frames)"
  # SKIP extraction — re-use existing frames
  FRAME_DIR="$EXISTING_DIR"
  FRAME_COUNT="$EXISTING_COUNT"
  # Baca index.md yang sudah ada
  cat "${FRAME_DIR}/index.md" 2>/dev/null
fi
```

**Aturan:**
- Jika `docs/video-frames/` sudah berisi frames DAN `docs/wave-execution-state.md` ada → SKIP extraction, re-use
- `/start resume` HARUS bisa menggunakan frames yang sudah di-extract sebelumnya
- JANGAN pernah hapus frames jika pipeline masih ongoing

## Cleanup Protocol

### Aturan Kapan Frames Boleh Dihapus

Frames HANYA dihapus saat:
1. **`/clean` command** dijalankan secara eksplisit oleh user
2. **Pipeline selesai SUKSES** — semua tasks di `docs/wave-execution-state.md` sudah `[x]`
3. **User eksplisit minta hapus** — misal via Telegram atau terminal

Frames TIDAK BOLEH dihapus jika:
- `docs/wave-execution-state.md` masih ada DAN berisi `[ ]` (incomplete tasks)
- Pipeline sedang berjalan (stage != complete)
- Saat `/start resume` — frames harus tetap tersedia

### Cleanup dengan Safety Check

```bash
# Safety check sebelum cleanup
WAVE_STATE="docs/wave-execution-state.md"
INCOMPLETE=$(grep -c '\[ \]' "$WAVE_STATE" 2>/dev/null || echo "0")

if [ "$INCOMPLETE" -gt 0 ]; then
  echo "SKIP cleanup: pipeline masih ada $INCOMPLETE incomplete tasks"
else
  rm -rf docs/video-frames/
  echo "Video frames cleaned up"
fi
```

### Manual (per video)

```bash
# Hapus frames dari satu video (hanya jika pipeline selesai)
rm -rf "docs/video-frames/${FRAME_ID}"
```

### Catatan cleanup:
- Frames bersifat TEMPORARY — generated artifacts, bukan source files
- `docs/video-frames/` sudah di-exclude dari git (via .gitignore)
- setup.sh/setup.ps1 TIDAK membersihkan frames saat re-deploy
- /clean command membersihkan frames sebagai bagian dari state cleanup
- `/start resume` TIDAK membersihkan frames — re-use yang sudah ada

## Context-Aware Frame Limits

Jumlah frame yang di-extract disesuaikan dengan scope pipeline agar tidak overload context window.

| Scope | Max Frames | Sampling Strategy | Alasan |
|-------|-----------|-------------------|--------|
| SMALL_EDIT | 10 | Keyframes saja | Scope kecil, context terbatas |
| BUG_FIX | 25 | Smart sampling (1-3s interval) | Use case utama video, butuh detail |
| BUILD (existing project) | 20 | Smart sampling (2-5s interval) | Referensi desain, perlu cukup detail |
| NEW_FEATURE | 15 | Smart sampling (3-5s interval) | Pipeline sudah token-heavy |
| GREENFIELD | 10 | Keyframes saja, interval besar | Pipeline paling token-heavy, video jarang dipakai di greenfield |
| DISCUSSION | 25 | Smart sampling (1-3s interval) | Analisis visual, butuh detail |

### Cara Penggunaan

Extraction command menerima `MAX_FRAMES` sebagai parameter. Default: 20 frames (jika scope belum diketahui saat PRE-PHASE).

Setelah scope classification, orchestrator adjust:
```bash
case "$SCOPE_TYPE" in
  SMALL_EDIT)  VIDEO_MAX_FRAMES=10 ;;
  BUG_FIX)     VIDEO_MAX_FRAMES=25 ;;
  NEW_FEATURE) VIDEO_MAX_FRAMES=15 ;;
  GREENFIELD)  VIDEO_MAX_FRAMES=10 ;;
  DISCUSSION)  VIDEO_MAX_FRAMES=25 ;;
  *)           VIDEO_MAX_FRAMES=20 ;;  # BUILD / default
esac
```

Jika frames sudah di-extract dengan jumlah lebih banyak dari limit scope:
- Agent hanya membaca **N frames yang evenly distributed** dari total set
- Contoh: 20 frames ter-extract, scope = GREENFIELD (limit 10) → baca frame 1, 3, 5, 7, 9, 11, 13, 15, 17, 19

```bash
# Evenly distributed frame selection
TOTAL_FRAMES=$FRAME_COUNT
LIMIT=$VIDEO_MAX_FRAMES
if [ "$TOTAL_FRAMES" -gt "$LIMIT" ]; then
  STEP=$(( TOTAL_FRAMES / LIMIT ))
  echo "Reading every ${STEP}th frame (${LIMIT} of ${TOTAL_FRAMES})"
fi
```

Orchestrator menuliskan limit ke pipeline-state.md:
```bash
echo "video_max_frames : $VIDEO_MAX_FRAMES" >> docs/pipeline-state.md
```

Agent yang membaca frames HARUS cek `video_max_frames` di pipeline-state.md dan batasi jumlah frame yang dibaca sesuai limit.

---

## Error Handling

### ffmpeg tidak terinstall
→ STOP. Tampilkan instruksi install sesuai OS (lihat Step 1).

### Format tidak didukung
→ List supported formats: .mp4, .mov, .webm, .avi, .mkv
→ Jika user punya format lain, suggest konversi manual: `ffmpeg -i input.xxx output.mp4`

### Video corrupt / tidak bisa dibaca
```bash
ffmpeg -v error -i "$VIDEO_FILE" -f null - 2>&1
```
Jika error → inform user: "Video file corrupt atau codec tidak didukung. Coba konversi ulang."

### Video terlalu panjang (>5 menit)
→ Warning di output, tapi tetap proses dengan sample frames (interval lebih besar)
→ Suggest user: "Untuk hasil terbaik, trim video ke bagian yang relevan saja (< 2 menit)."

### Tidak ada frames ter-extract (video terlalu pendek / error)
→ Fallback: extract single frame di detik ke-0
```bash
ffmpeg -i "$VIDEO_FILE" -vframes 1 -q:v 3 "${FRAME_DIR}/frame_0001.jpg" 2>/dev/null
```

## Cross-Platform Notes

- ffmpeg command syntax IDENTIK di Linux, macOS, dan Windows (native PowerShell)
- Path separator: gunakan forward slash (/) — ffmpeg di Windows support ini
- Windows path conversion (C:\Users\... → /mnt/c/Users/...) sudah dihandle oleh start.md
- Di WSL: ffmpeg diinstall via apt (bukan Windows ffmpeg)
- Di native Windows PowerShell: ffmpeg diinstall via winget/choco, jalan native
