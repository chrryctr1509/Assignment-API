#!/usr/bin/env bun
// dispatcher.ts — Cross-platform hook router for Claude Team Agents
//
// Usage: bun dispatcher.ts <hook-name> [extra-args...]
// Detects OS -> runs .sh (Linux/macOS/WSL) or .ps1 (Windows)
//
// Reads stdin (hook input JSON from Claude Code) and passes it through
// to the platform-specific script. Exit code is preserved.

import { $ } from "bun";
import { join, dirname } from "path";
import { existsSync } from "fs";
import { fileURLToPath } from "url";

const hookName = process.argv[2];
if (!hookName) {
  console.error("Usage: bun dispatcher.ts <hook-name>");
  process.exit(1);
}

// fileURLToPath handles Windows drive-letter paths correctly
// (new URL().pathname returns "/C:/..." on Windows which breaks existsSync)
const hooksDir = dirname(fileURLToPath(import.meta.url));
const isWindows = process.platform === "win32";

// Read stdin (hook input JSON from Claude Code)
let stdinData = "";
try {
  const chunks: Buffer[] = [];
  for await (const chunk of Bun.stdin.stream()) {
    chunks.push(Buffer.from(chunk));
  }
  stdinData = Buffer.concat(chunks).toString("utf-8");
} catch {
  // No stdin is OK for some hooks (e.g., Stop hooks)
}

if (isWindows) {
  // Windows: run PowerShell script
  const ps1Path = join(hooksDir, `${hookName}.ps1`);
  if (!existsSync(ps1Path)) {
    // Fallback: try bash via Git Bash if .ps1 doesn't exist
    const shPath = join(hooksDir, `${hookName}.sh`);
    if (existsSync(shPath)) {
      const proc = Bun.spawn(["bash", shPath, ...process.argv.slice(3)], {
        stdin: new Blob([stdinData]),
        stdout: "inherit",
        stderr: "inherit",
        env: process.env,
      });
      const exitCode = await proc.exited;
      process.exit(exitCode);
    }
    console.error(`Hook not found: ${hookName} (tried .ps1 and .sh)`);
    process.exit(1);
  }

  const proc = Bun.spawn(
    ["powershell", "-ExecutionPolicy", "Bypass", "-File", ps1Path, ...process.argv.slice(3)],
    {
      stdin: new Blob([stdinData]),
      stdout: "inherit",
      stderr: "inherit",
      env: process.env,
    }
  );
  const exitCode = await proc.exited;
  process.exit(exitCode);
} else {
  // Linux/macOS/WSL: run Bash script
  const shPath = join(hooksDir, `${hookName}.sh`);
  if (!existsSync(shPath)) {
    console.error(`Hook not found: ${shPath}`);
    process.exit(1);
  }

  const proc = Bun.spawn(["bash", shPath, ...process.argv.slice(3)], {
    stdin: new Blob([stdinData]),
    stdout: "inherit",
    stderr: "inherit",
    env: process.env,
  });
  const exitCode = await proc.exited;
  process.exit(exitCode);
}
