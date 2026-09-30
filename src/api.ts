import { readdir } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { Failure, loginExpired } from "./failure";

// The endpoint is undocumented, so every field is optional here and checked in snapshot.ts.
export type RawWindow = { utilization?: number | null; resets_at?: string | null };

export type RawLimit = {
	kind?: string;
	percent?: number | null;
	severity?: string;
	resets_at?: string | null;
	scope?: { model?: { display_name?: string | null } | null } | null;
};

export type RawUsage = {
	five_hour?: RawWindow | null;
	seven_day?: RawWindow | null;
	limits?: RawLimit[] | null;
	extra_usage?: {
		is_enabled?: boolean;
		monthly_limit?: number | null;
		used_credits?: number | null;
		currency?: string | null;
	} | null;
	seven_day_breakdown?: { rows?: { display_name?: string; percent?: number }[] | null } | null;
	/** Usage-limit resets the account has been granted; only present when asked for with cedar_ember=1. */
	cedar_ember?: { grants?: RawGrant[] | null } | null;
};

export type RawGrant = {
	label?: string;
	resets_left?: number;
	ends_at?: string | null;
	usable_now?: boolean;
	paused?: boolean;
};

const ENDPOINT = "https://api.anthropic.com/api/oauth/usage?cedar_ember=1";
const FIRST_BACKOFF_SECONDS = 300;
const MAX_BACKOFF_SECONDS = 1800;
const FALLBACK_VERSION = "2.1.285";

// The server answers other clients from a bucket that returns 429 for hours, and lists
// reset grants only for Claude Code, so burnbar identifies as the installed Claude Code.
async function userAgent(): Promise<string> {
	const installed = await readdir(join(homedir(), ".local", "share", "claude", "versions")).catch(() => []);
	const versions = installed.filter((name) => /^\d+(\.\d+)+$/.test(name));
	versions.sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
	return `claude-cli/${versions.at(-1) ?? FALLBACK_VERSION} (external, cli)`;
}

/** `previousBackoff` is the wait after the last 429 in a row, in seconds, or 0. */
export async function fetchUsage(accessToken: string, previousBackoff = 0, now = Date.now()): Promise<RawUsage> {
	const headers = {
		Authorization: `Bearer ${accessToken}`,
		"anthropic-beta": "oauth-2025-04-20",
		"User-Agent": await userAgent(),
		Accept: "application/json",
	};
	const response = await fetch(ENDPOINT, { headers, signal: AbortSignal.timeout(15_000) }).catch(() => {
		throw new Failure(
			"Cannot reach Anthropic",
			"No answer from api.anthropic.com. Check the connection or the VPN. Burnbar tries again at the next refresh; until then the last reading is shown.",
		);
	});
	if (response.status === 429) {
		// Each 429 in a row doubles the wait, unless the server says how long to wait.
		const doubled = previousBackoff ? Math.min(previousBackoff * 2, MAX_BACKOFF_SECONDS) : FIRST_BACKOFF_SECONDS;
		const seconds = Number(response.headers.get("retry-after")) || doubled;
		throw new Failure(
			"Usage checks are rate limited",
			"Anthropic limits how often usage can be read, and it was read too often. Your Claude usage and limits are not affected. Burnbar waits and tries again by itself; until then the last reading is shown.",
			now + seconds * 1000,
			seconds,
		);
	}
	if (response.status === 401) throw loginExpired();
	if (response.status === 403)
		throw new Failure(
			"This login cannot read usage",
			"Anthropic refused the request. Usage limits exist only for a Claude subscription: sign in to Claude Code with `claude`, not with an API key or a token from `claude setup-token`.",
		);
	if (!response.ok)
		throw new Failure(
			`Anthropic answered HTTP ${response.status}`,
			"The usage endpoint is not documented by Anthropic and may have changed or be down. If this lasts, look for a newer burnbar.",
		);
	return (await response.json().catch(() => {
		throw new Failure(
			"Anthropic answered something unreadable",
			"The usage endpoint is not documented by Anthropic and may have changed. If this lasts, look for a newer burnbar.",
		);
	})) as RawUsage;
}
