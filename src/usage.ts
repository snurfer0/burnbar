import { lastActivity } from "./activity";
import { fetchUsage } from "./api";
import { ageSeconds, readCache, writeCache } from "./cache";
import { readCredentials } from "./credentials";
import { describe, loginExpired } from "./failure";
import { accountSuffix } from "./files";
import { track } from "./history";
import { buildSnapshot, failedSnapshot, type Snapshot } from "./snapshot";

// While Claude Code is idle the limits barely move, so a reading is kept this long.
const IDLE_MAX_AGE_SECONDS = 900;
// Usage from the last turn can reach the endpoint a little after the turn ended.
const ACTIVITY_GRACE_MS = 120_000;

/** The current usage of the account in `dir`, from the cache while it is fresh enough. */
export async function readUsage(maxAge: number, dir: string): Promise<Snapshot> {
	const account = accountSuffix(dir);
	const cached = await readCache(account);
	const now = Date.now();
	if (cached?.retryAt && Date.parse(cached.retryAt) > now) return cached;
	if (cached?.ok && !cached.stale && cached.fetchedAt && maxAge > 0) {
		const age = ageSeconds(cached, now);
		if (age < maxAge) return cached;
		const idle = (await lastActivity(dir)) < Date.parse(cached.fetchedAt) - ACTIVITY_GRACE_MS;
		if (idle && age < IDLE_MAX_AGE_SECONDS) return cached;
	}
	try {
		const credentials = await readCredentials(dir);
		if (credentials.expiresAt < now) throw loginExpired();
		const raw = await fetchUsage(credentials.accessToken, cached?.backoffSeconds ?? 0, now);
		const fresh = buildSnapshot(raw, credentials.plan, now);
		fresh.limits = await track(fresh.limits, account, now);
		await writeCache(account, fresh);
		return fresh;
	} catch (error) {
		const failed = failedSnapshot(describe(error), cached);
		// A back-off has to outlive this process, so it goes into the cache.
		if (failed.retryAt) await writeCache(account, failed).catch(() => {});
		return failed;
	}
}
