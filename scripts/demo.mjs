/**
 * Demo recording script for sample_cicd Web UI
 * Captures screenshots of task creation → completion flow
 * Usage: node scripts/demo.mjs
 */

import { chromium } from "playwright";
import { mkdirSync, rmSync, existsSync } from "fs";
import { execSync } from "child_process";
import path from "path";

const BASE_URL = process.env.DEMO_URL || "http://localhost:5173";
const OUT_DIR = path.resolve("scripts/frames");
const GIF_PATH = path.resolve("docs/demo.gif");

let frameIndex = 0;

async function shot(page, label) {
  const file = path.join(OUT_DIR, `${String(frameIndex).padStart(3, "0")}_${label}.png`);
  await page.screenshot({ path: file, fullPage: false });
  console.log(`  📸 ${label}`);
  frameIndex++;
}

async function wait(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function main() {
  // Setup output directory
  if (existsSync(OUT_DIR)) rmSync(OUT_DIR, { recursive: true });
  mkdirSync(OUT_DIR, { recursive: true });

  console.log(`\n🎬 Starting demo recording...`);
  console.log(`   URL: ${BASE_URL}\n`);

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1080, height: 720 },
    deviceScaleFactor: 1.5,
  });
  const page = await context.newPage();

  // ── Step 1: Task list (empty or existing) ───────────────────────────────
  await page.goto(BASE_URL, { waitUntil: "networkidle" });
  await wait(800);
  await shot(page, "01_task_list");

  // ── Step 2: Click "New Task" ─────────────────────────────────────────────
  await page.click('a[href="/tasks/new"]');
  await page.waitForURL("**/tasks/new", { waitUntil: "networkidle" });
  await wait(400);
  await shot(page, "02_new_task_form");

  // ── Step 3: Fill in form ─────────────────────────────────────────────────
  await page.fill("#title", "v6デモタスク");
  await wait(300);
  await shot(page, "03_title_filled");

  await page.fill("#description", "sample_cicd v6 のデモ用タスクです。");
  await wait(300);
  await shot(page, "04_description_filled");

  // ── Step 4: Submit ───────────────────────────────────────────────────────
  await page.click('button[type="submit"]');
  await page.waitForURL("**/tasks/**", { waitUntil: "networkidle" });
  await wait(600);
  await shot(page, "05_task_detail");

  // ── Step 5: Mark Complete ────────────────────────────────────────────────
  await page.click('button:has-text("Mark Complete")');
  await wait(800);
  await shot(page, "06_task_completed");

  // ── Step 6: Back to list ─────────────────────────────────────────────────
  await page.click('button:has-text("Back to tasks")');
  await page.waitForURL(BASE_URL + "/", { waitUntil: "networkidle" });
  await wait(600);
  await shot(page, "07_list_with_completed");

  // ── Step 7: Filter Completed ─────────────────────────────────────────────
  await page.click('button:has-text("Completed")');
  await wait(400);
  await shot(page, "08_filter_completed");

  await browser.close();
  console.log(`\n✅ ${frameIndex} frames captured`);

  // ── Build GIF with ffmpeg ────────────────────────────────────────────────
  console.log("\n🎞️  Building GIF...");
  // Build GIF: each frame shown for 2 seconds via setpts
  execSync(
    `ffmpeg -y \
      -framerate 1 \
      -pattern_type glob -i '${OUT_DIR}/*.png' \
      -vf "setpts=0.5*PTS,fps=0.5,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer" \
      -loop 0 \
      "${GIF_PATH}"`,
    { stdio: "inherit" }
  );

  console.log(`\n🎉 GIF saved to: ${GIF_PATH}`);
  rmSync(OUT_DIR, { recursive: true });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
