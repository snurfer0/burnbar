import { createHash } from "node:crypto";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

export const CACHE_DIR = join(process.env.XDG_CACHE_HOME || join(homedir(), ".cache"), "burnbar");
export const STATE_DIR = join(process.env.XDG_STATE_HOME || join(homedir(), ".local", "state"), "burnbar");

const DEFAULT_CLAUDE_DIR = join(homedir(), ".claude");

/** The folder Claude Code keeps its login in: an explicit choice, then CLAUDE_CONFIG_DIR, then ~/.claude. */
export function claudeDir(explicit?: string): string {
	const chosen = explicit || process.env.CLAUDE_CONFIG_DIR || DEFAULT_CLAUDE_DIR;
	return resolve(chosen.replace(/^~(?=$|\/)/, homedir()));
}

/** Suffix that keeps the cache and history of a second account apart from the default one. */
export function accountSuffix(dir: string): string {
	return dir === DEFAULT_CLAUDE_DIR ? "" : `-${createHash("sha1").update(dir).digest("hex").slice(0, 8)}`;
}

export async function readText(path: string): Promise<string | null> {
	try {
		return await readFile(path, "utf8");
	} catch {
		return null;
	}
}

// Rename is atomic, so a widget reading at the same moment never sees half a file.
export async function writeText(path: string, text: string): Promise<void> {
	await mkdir(dirname(path), { recursive: true });
	const temporary = `${path}.${process.pid}.tmp`;
	await writeFile(temporary, text);
	await rename(temporary, path);
}
