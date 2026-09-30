import { appendFile, mkdir } from "node:fs/promises";
import { join } from "node:path";
import { readText, STATE_DIR, writeText } from "./files";
import type { Limit, Sample } from "./snapshot";

type Entry = { t: number; v: Record<string, number> };

const path = (account: string) => join(STATE_DIR, `history${account}.jsonl`);
const KEEP_SECONDS = 8 * 86_400;
// An unchanged reading is only written this often, which keeps a week of history near 100 kB.
const HEARTBEAT_SECONDS = 900;
const MAX_POINTS = 120;

/** Records this reading and returns the limits with the history of their current window. */
export async function track(limits: Limit[], account: string, now = Date.now()): Promise<Limit[]> {
	const file = path(account);
	const seconds = Math.round(now / 1000);
	const entries = parse(await readText(file));
	const current: Entry = { t: seconds, v: Object.fromEntries(limits.map((limit) => [limit.id, limit.percent])) };
	const last = entries.at(-1);

	if (!last || seconds - last.t >= HEARTBEAT_SECONDS || !same(last.v, current.v)) {
		const first = entries[0];
		if (first && seconds - first.t > KEEP_SECONDS * 1.25) {
			const kept = entries.filter((entry) => seconds - entry.t <= KEEP_SECONDS);
			await writeText(file, [...kept, current].map((entry) => `${JSON.stringify(entry)}\n`).join(""));
		} else {
			await mkdir(STATE_DIR, { recursive: true });
			await appendFile(file, `${JSON.stringify(current)}\n`);
		}
	}
	entries.push(current);

	return limits.map((limit) => ({ ...limit, history: windowHistory(limit, entries) }));
}

function windowHistory(limit: Limit, entries: Entry[]): Sample[] {
	if (!limit.resetsAt) return [];
	const start = Date.parse(limit.resetsAt) / 1000 - limit.windowHours * 3600;
	const samples: Sample[] = [];
	for (const entry of entries) {
		const percent = entry.v[limit.id];
		if (entry.t >= start && percent !== undefined) samples.push([entry.t, percent]);
	}
	return thin(samples);
}

function thin(samples: Sample[]): Sample[] {
	if (samples.length <= MAX_POINTS) return samples;
	const step = (samples.length - 1) / (MAX_POINTS - 1);
	return Array.from({ length: MAX_POINTS }, (_, index) => samples[Math.round(index * step)] as Sample);
}

function parse(text: string | null): Entry[] {
	const entries: Entry[] = [];
	for (const line of (text ?? "").split("\n")) {
		if (!line) continue;
		try {
			const entry = JSON.parse(line) as Entry;
			if (typeof entry.t === "number" && entry.v) entries.push(entry);
		} catch {
			// a line cut short by a crash is skipped
		}
	}
	return entries;
}

function same(a: Record<string, number>, b: Record<string, number>): boolean {
	const keys = Object.keys(a);
	return keys.length === Object.keys(b).length && keys.every((key) => a[key] === b[key]);
}
