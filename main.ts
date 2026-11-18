// Snackrot Bay: the hand-in program for make.fun's roblox-brainrot-01.
// It gathers the entry's files from beside this file into the output
// directory and writes the dossier the judge reads, using the vendored
// make.fun library. Node 22, standard library only.
//
// The Rojo project in this directory is built into game.rbxl first:
//   rojo build default.project.json --output game.rbxl
// Then the grader runs this program, twice, and both runs must agree:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildDossier } from "./vendor/makefun-roblox.ts";

// The repository root (this file's directory) and the output directory.
// The grader sets MAKEFUN_OUTPUT_DIR to /output; outside it, out/ stands in.
const repoRoot = fileURLToPath(new URL(".", import.meta.url));
const outputDir = process.env.MAKEFUN_OUTPUT_DIR ?? "/output";

// The gate refuses any name under /output that starts with a dot, so the
// copies below skip dotted names at every depth (.gitkeep, .DS_Store, .git).
function isVisible(path: string): boolean {
	return !basename(path).startsWith(".");
}

// Copy one file, failing loudly if it is missing: a half-written output
// would fail the gate anyway, and silence here would only hide it.
function copyEntryFile(name: string): void {
	const from = join(repoRoot, name);
	const to = join(outputDir, name);
	if (!existsSync(from)) {
		throw new Error(`missing entry file: ${name}`);
	}
	copyFileSync(from, to);
}

// Copy a whole directory of entry files, visible names only.
function copyEntryDir(name: string): void {
	const from = join(repoRoot, name);
	const to = join(outputDir, name);
	if (!existsSync(from)) {
		throw new Error(`missing entry directory: ${name}`);
	}
	cpSync(from, to, { recursive: true, filter: isVisible });
}

// Refuse to hand in an entry whose screenshots break the gate's own caps:
// at most 4 images, each at most 256 KiB. The dossier writer enforces the
// same caps, but failing here names the file instead of failing the dossier.
function checkScreenshots(): void {
	const dir = join(repoRoot, "screenshots");
	const names = readdirSync(dir).filter(isVisible).sort();
	if (names.length < 3 || names.length > 4) {
		throw new Error(`screenshots: expected 3 or 4 images, found ${names.length}`);
	}
	for (const name of names) {
		const bytes = statSync(join(dir, name)).size;
		if (bytes > 262144) {
			throw new Error(`screenshots/${name} is ${bytes} bytes, over the 256 KiB cap`);
		}
	}
}

// Report what was handed in, with sizes, so a failed gate can be traced
// to a file without re-listing the output directory by hand.
function reportOutput(): void {
	const names = ["game.rbxl", "PLAY.json", "dossier.json"];
	for (const name of names) {
		const bytes = statSync(join(outputDir, name)).size;
		console.log(`  ${name}: ${bytes} bytes`);
	}
	const shots = readdirSync(join(outputDir, "screenshots")).filter(isVisible).sort();
	for (const name of shots) {
		const bytes = statSync(join(outputDir, "screenshots", name)).size;
		console.log(`  screenshots/${name}: ${bytes} bytes`);
	}
	const scripts = readdirSync(join(outputDir, "src"), { recursive: true })
		.filter((entry) => typeof entry === "string" && entry.endsWith(".luau"))
		.sort();
	console.log(`  src/: ${scripts.length} Luau scripts`);
}

mkdirSync(outputDir, { recursive: true });
copyEntryFile("game.rbxl");
copyEntryFile("PLAY.json");
copyEntryDir("src");
checkScreenshots();
copyEntryDir("screenshots");

// The dossier is byte for byte what the vendored library writes from the
// files above, with the gate's caps: 64 KiB of script text, at most 4
// screenshots of at most 256 KiB, at most 500,000 place instances, scripts
// of at most 8 MiB of source in all, and script paths of at most
// 1,048,576 characters in all.
writeFileSync(
	join(outputDir, "dossier.json"),
	buildDossier(outputDir, {
		text_max_bytes: 65536,
		screenshots: { max: 4, max_bytes: 262144 },
		max_instances: 500000,
		scripts_max_source_bytes: 8388608,
		scripts_max_path_chars: 1048576,
	}),
);

console.log("Snackrot Bay handed in: game.rbxl, src/, screenshots/, PLAY.json and dossier.json are in " + outputDir);
reportOutput();
