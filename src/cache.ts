import { join } from "node:path";
import { CACHE_DIR, readText, writeText } from "./files";
import type { Snapshot } from "./snapshot";

const path = (account: string) => join(CACHE_DIR, `snapshot${account}.json`);

export async function readCache(account: string): Promise<Snapshot | null> {
	try {
		const snapshot = JSON.parse((await readText(path(account))) ?? "") as Snapshot;
		return Array.isArray(snapshot.limits) ? snapshot : null;
	} catch {
		return null;
	}
}

export async function writeCache(account: string, snapshot: Snapshot): Promise<void> {
	await writeText(path(account), JSON.stringify(snapshot));
}

export function ageSeconds(snapshot: Snapshot, now = Date.now()): number {
	return snapshot.fetchedAt ? (now - Date.parse(snapshot.fetchedAt)) / 1000 : Number.POSITIVE_INFINITY;
}
