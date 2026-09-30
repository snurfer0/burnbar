import type { RawLimit, RawUsage } from "./api";
import type { Problem } from "./failure";

/** One usage reading: [unix seconds, percent]. */
export type Sample = [number, number];

export type Limit = {
	id: string;
	label: string;
	percent: number;
	resetsAt: string | null;
	windowHours: number;
	severity: string;
	/** Percent the window ends at if the current average rate holds. Null early in a window. */
	projected: number | null;
	/** When the limit is reached at the current rate, if that is before the reset. */
	hitsAt: string | null;
	/** Readings from the current window, oldest first. */
	history: Sample[];
};

export type Snapshot = {
	ok: boolean;
	error: string | null;
	/** What the error means and what happens next, in a sentence or two. */
	hint: string | null;
	stale: boolean;
	fetchedAt: string | null;
	/** Set after a 429: no request is made before this time. */
	retryAt: string | null;
	/** The wait that led to retryAt, in seconds: the next 429 in a row doubles it. */
	backoffSeconds: number;
	plan: string;
	limits: Limit[];
	breakdown: { label: string; percent: number }[];
	extra: { used: number; limit: number | null; currency: string } | null;
	/** A usage-limit reset the account can still spend (with /limit-reset in Claude Code). */
	reset: { label: string; left: number; endsAt: string | null; usable: boolean } | null;
};

const HOUR = 3_600_000;
const MINUTE = 60_000;
const SESSION_HOURS = 5;
const WEEK_HOURS = 168;

// A projection from the first few percent of a window swings wildly.
const MIN_ELAPSED = 0.05;

export function buildSnapshot(raw: RawUsage, plan: string, now = Date.now()): Snapshot {
	return {
		ok: true,
		error: null,
		hint: null,
		stale: false,
		fetchedAt: new Date(now).toISOString(),
		retryAt: null,
		backoffSeconds: 0,
		plan,
		limits: rawLimits(raw).map((limit) => toLimit(limit, now)),
		breakdown: (raw.seven_day_breakdown?.rows ?? [])
			.filter((row) => row.display_name && (row.percent ?? 0) > 0)
			.map((row) => ({ label: row.display_name as string, percent: row.percent as number })),
		extra: raw.extra_usage?.is_enabled
			? {
					used: raw.extra_usage.used_credits ?? 0,
					limit: raw.extra_usage.monthly_limit ?? null,
					currency: raw.extra_usage.currency ?? "USD",
				}
			: null,
		reset: toReset(raw),
	};
}

function toReset(raw: RawUsage): Snapshot["reset"] {
	const grant = (raw.cedar_ember?.grants ?? []).find((candidate) => (candidate.resets_left ?? 0) > 0);
	if (!grant) return null;
	return {
		label: grant.label ?? "Usage-limit reset",
		left: grant.resets_left ?? 0,
		endsAt: normaliseTime(grant.ends_at),
		usable: grant.usable_now === true && grant.paused !== true,
	};
}

export function failedSnapshot(problem: Problem, cached: Snapshot | null): Snapshot {
	const failure = {
		error: problem.message,
		hint: problem.hint,
		retryAt: problem.retryAt === null ? null : new Date(problem.retryAt).toISOString(),
		backoffSeconds: problem.backoffSeconds,
	};
	if (cached?.ok) return { ...cached, ...failure, stale: true };
	return {
		ok: false,
		stale: false,
		fetchedAt: null,
		plan: "",
		limits: [],
		breakdown: [],
		extra: null,
		reset: null,
		...failure,
	};
}

// Older responses only carry five_hour and seven_day; newer ones add the per-model limits.
function rawLimits(raw: RawUsage): RawLimit[] {
	if (raw.limits?.length) return raw.limits;
	const limits: RawLimit[] = [];
	if (raw.five_hour)
		limits.push({ kind: "session", percent: raw.five_hour.utilization, resets_at: raw.five_hour.resets_at });
	if (raw.seven_day)
		limits.push({ kind: "weekly_all", percent: raw.seven_day.utilization, resets_at: raw.seven_day.resets_at });
	return limits;
}

function toLimit(raw: RawLimit, now: number): Limit {
	const kind = raw.kind ?? "unknown";
	const model = raw.scope?.model?.display_name;
	const percent = Math.max(0, Math.round(raw.percent ?? 0));
	const resetsAt = normaliseTime(raw.resets_at);
	const session = kind === "session";
	const windowHours = session ? SESSION_HOURS : WEEK_HOURS;
	return {
		id: model ? `${kind}:${model.toLowerCase()}` : kind,
		label: session ? "Session" : model ? `Weekly ${model}` : kind === "weekly_all" ? "Weekly" : kind,
		percent,
		resetsAt,
		windowHours,
		severity: raw.severity ?? "normal",
		...pace(percent, resetsAt, windowHours * HOUR, now),
		history: [],
	};
}

// The API jitters the same reset time by up to a second between calls; a stable value
// lets the widget tell one window from the next.
function normaliseTime(iso?: string | null): string | null {
	const time = iso ? Date.parse(iso) : Number.NaN;
	return Number.isNaN(time) ? null : new Date(Math.round(time / MINUTE) * MINUTE).toISOString();
}

export function pace(
	percent: number,
	resetsAt: string | null,
	windowMs: number,
	now: number,
): Pick<Limit, "projected" | "hitsAt"> {
	const none = { projected: null, hitsAt: null };
	if (!resetsAt) return none;
	const reset = Date.parse(resetsAt);
	const elapsed = windowMs - (reset - now);
	if (elapsed < windowMs * MIN_ELAPSED || elapsed > windowMs) return none;
	if (percent >= 100) return { projected: Math.round((percent / elapsed) * windowMs), hitsAt: null };
	if (percent <= 0) return { projected: 0, hitsAt: null };
	const rate = percent / elapsed;
	const hit = now + (100 - percent) / rate;
	return { projected: Math.round(rate * windowMs), hitsAt: hit < reset ? new Date(hit).toISOString() : null };
}
