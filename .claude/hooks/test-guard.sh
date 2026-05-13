#!/bin/bash
# test-guard.sh — Warn jika git commit dijalankan tanpa recent test run
# Hook type: PreToolUse (Bash)
#
# PENTING: Hook ini TIDAK ter-register di settings.json sebagai standalone hook.
# Sebagai gantinya, git-manager.md memanggil logic ini via Pre-Commit Regression Gate.
# Alasan: git-delegation-guard.sh sudah intercept Bash matcher untuk git commands.
# Menambah hook kedua akan double-trigger dan menyebabkan conflict.
#
# Jika user memang mau register ini (opsional), pastikan hook HANYA output warn
# (JSON decision), bukan exit 2 (block). git-delegation-guard.sh yang block;
# test-guard.sh hanya warn git-manager bahwa test belum pass.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  echo '{"decision": "pass"}'
  exit 0
fi

# Only trigger pada git commit
if echo "$COMMAND" | grep -q "git commit"; then
  # Cek apakah test sudah dijalankan dalam 30 menit terakhir
  if [ ! -f "/tmp/pre-commit-test.log" ] || [ -n "$(find /tmp/pre-commit-test.log -mmin +30 2>/dev/null)" ]; then
    echo '{"decision": "warn", "message": "⚠️ REGRESSION GUARD: git commit detected tanpa recent test run (<30 menit). Jalankan test suite dulu sebelum commit (npm test / pytest / php artisan test)."}'
    exit 0
  fi

  # Cek result dari test terakhir
  if grep -qiE "fail|error|FAILED" /tmp/pre-commit-test.log 2>/dev/null; then
    echo '{"decision": "warn", "message": "⚠️ REGRESSION GUARD: Test terakhir ada FAILURE. Review /tmp/pre-commit-test.log sebelum commit. Jika pre-existing, commit dengan note di message."}'
    exit 0
  fi

  echo '{"decision": "pass"}'
  exit 0
fi

echo '{"decision": "pass"}'
exit 0
