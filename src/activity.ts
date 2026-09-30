import { readdir, stat } from "node:fs/promises";
import { join } from "node:path";

/**
 * When Claude Code last wrote something in this folder, in unix milliseconds, or 0.
 * Prompts land in history.jsonl and every model turn in a transcript under projects/,
 * so this moves whenever usage can have moved.
 */
export async function lastActivity(claudeDir: string): Promise<number> {
	const projects = join(claudeDir, "projects");
	const files = [join(claudeDir, "history.jsonl")];
	for (const project of await list(projects)) {
		for (const name of await list(join(projects, project))) {
			if (name.endsWith(".jsonl")) files.push(join(projects, project, name));
		}
	}
	const times = await Promise.all(
		files.map((file) =>
			stat(file).then(
				(info) => info.mtimeMs,
				() => 0,
			),
		),
	);
	return Math.max(0, ...times);
}

function list(dir: string): Promise<string[]> {
	return readdir(dir).catch(() => []);
}
