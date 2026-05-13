# Security Configuration
# File ini adalah sumber kebenaran untuk security-check.
# Perubahan bisa diusulkan oleh security-learner (adaptive learning)
# dan auto-apply setelah 24 jam jika tidak di-reject programmer.
#
# Format entry allow list:
# - operasi : deskripsi
#   added   : YYYY-MM-DD
#   source  : MANUAL / LEARNED
#   reason  : kenapa ini aman / kenapa dipelajari

---

## ⚠️ IMMUTABLE RULES
# Rules ini TIDAK PERNAH bisa diubah oleh adaptive learning.
# Tidak peduli berapa kali di-APPROVE — tetap BLOCK selamanya.

NEVER ALLOW — tidak bisa di-override oleh siapapun:
- git push origin main (dalam bentuk apapun)
- git push origin develop (dalam bentuk apapun)
- git push --force (ke target manapun)
- git add .env (atau file credentials apapun)
- git commit dengan .env ter-include
- DROP DATABASE
- Push credentials/secrets ke remote manapun

---

## ALLOW LIST — Database Operations

ALLOW (aman, tidak perlu flag):
- SELECT — semua bentuk query read
  added: init | source: MANUAL
- INSERT dengan data eksplisit dan terbatas
  added: init | source: MANUAL
- UPDATE dengan WHERE clause spesifik dan terverifikasi
  added: init | source: MANUAL
- Menjalankan migration UP (tambah tabel/kolom)
  added: init | source: MANUAL

ALWAYS FLAG — minta approval programmer:
- DELETE tanpa WHERE
- DELETE dengan WHERE yang broad (WHERE 1=1, WHERE id > 0)
- DROP TABLE
- TRUNCATE TABLE
- UPDATE tanpa WHERE
- ALTER TABLE DROP COLUMN
- migration rollback / migrate DOWN
- Raw SQL yang mengandung DELETE/DROP/TRUNCATE

---

## ALLOW LIST — Git Operations

ALLOW (aman, tidak perlu flag):
- git status, git log, git diff, git branch
  added: init | source: MANUAL
- git add <specific files> (bukan .env atau credentials)
  added: init | source: MANUAL
- git commit
  added: init | source: MANUAL
- git checkout -b feat/* (dari develop)
  added: init | source: MANUAL
- git push origin feat/* (ke feature branch sendiri)
  added: init | source: MANUAL
- git pull origin develop
  added: init | source: MANUAL
- git stash
  added: init | source: MANUAL
- git fetch origin <base_branch>
  added: 2026-03-15 | source: MANUAL
  reason: sync remote state sebelum push — read-only fetch, tidak mengubah branch lokal
- git merge origin/develop (sync feature branch dari base — bukan protected branch write)
  added: 2026-03-15 | source: MANUAL
  reason: pr-creator LANGKAH 1.5 — sync base branch sebelum push untuk hindari conflict di remote

ALWAYS FLAG — minta approval programmer:
- git push ke branch selain feat/* (kecuali NEVER ALLOW)
- git reset --hard
- git rebase

---

## ALLOW LIST — Credentials & Secrets

ALLOW (aman, tidak perlu flag):
- Membaca .env.example
  added: init | source: MANUAL
- Membaca docs/environment-setup.md
  added: init | source: MANUAL
- Generate random string untuk key (tanpa menulis ke file)
  added: init | source: MANUAL

ALWAYS FLAG — minta approval programmer:
- Menulis ke file .env
- Membaca nilai aktual dari .env (log/print)
- Membuat file baru yang mengandung credentials

---

## LEARNED RULES (diisi oleh adaptive learning)
# Section ini dikelola oleh security-learner.
# Setiap entry punya expiry proposal 24 jam.
# Jika tidak di-reject → auto-apply.

<!-- adaptive learning akan append di sini -->

---

## KONTEKS PROJECT

protected-branches: main, develop, staging
feature-branch-format: feat/[nomor]-[nama]
merge-strategy: Merge Request via GitLab only
database-engine: [isi sesuai project]
env-files: .env, .env.local, .env.production

---

## RIWAYAT PERUBAHAN

| Tanggal | Perubahan | Source | Alasan |
|---------|-----------|--------|--------|
| init    | File dibuat | MANUAL | Initial security config |
