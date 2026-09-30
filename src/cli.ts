#!/usr/bin/env bun
import { parseArgs } from "node:util";
import { claudeDir } from "./files";
import type { Limit, Snapshot } from "./snapshot";
import { checkUpdate, installUpdate, type UpdateStatus, VERSION } from "./update";
import { readUsage } from "./usage";

const HELP = `burnbar ${VERSION}: Claude Code usage limits

  burnbar                 print a readable summary
  burnbar update          install the latest release over the panel widget
  burnbar update --check  only say whether there is one
  --json                  print JSON (what the panel widget reads)
  --max-age <seconds>     reuse the last answer if it is younger than this (default 60, and a
                          day for update checks); 0 always asks again
  --config-dir <path>     Claude Code folder to read the login from (default: $CLAUDE_CONFIG_DIR
                          or ~/.claude)
  -h, --help              show this help`;

function span(ms: number): string {
	const minutes = Math.max(0, Math.round(ms / 60_000));
	const days = Math.floor(minutes / 1440);
	const hours = Math.floor((minutes % 1440) / 60);
	if (days) return `${days}d ${hours}h`;
	return hours ? `${hours}h ${minutes % 60}m` : `${minutes}m`;
}

function line(limit: Limit, now: number): string {
	const filled = Math.round(Math.min(limit.percent, 100) / 5);
	const bar = "█".repeat(filled) + "░".repeat(20 - filled);
	const reset = limit.resetsAt ? `  resets in ${span(Date.parse(limit.resetsAt) - now)}` : "";
	const forecast = limit.hitsAt
		? `  full in ${span(Date.parse(limit.hitsAt) - now)}`
		: limit.projected !== null
			? `  on pace for ${limit.projected}%`
			: "";
	return `${limit.label.padEnd(14)} ${bar} ${String(limit.percent).padStart(3)}%${reset}${forecast}`;
}

function renderUsage(s: Snapshot, now = Date.now()): string {
	if (!s.ok) return `burnbar: ${s.error}${s.hint ? `\n${s.hint}` : ""}`;
	const lines = s.limits.map((limit) => line(limit, now));
	if (s.plan) lines.unshift(`Claude ${s.plan}`);
	if (s.breakdown.length)
		lines.push(`This week: ${s.breakdown.map((row) => `${row.label} ${row.percent}%`).join(", ")}`);
	if (s.extra) {
		const of = s.extra.limit === null ? "" : ` of ${s.extra.limit}`;
		lines.push(`Extra usage: ${s.extra.used}${of} ${s.extra.currency}`);
	}
	if (s.reset) {
		const until = s.reset.endsAt ? `, use by ${s.reset.endsAt.slice(0, 10)}` : "";
		lines.push(`Limit reset available: ${s.reset.left}${until} (/limit-reset in Claude Code)`);
	}
	if (s.stale && s.fetchedAt) {
		const retry = s.retryAt ? `, next try in ${span(Date.parse(s.retryAt) - now)}` : "";
		lines.push("", `${s.error}: reading is ${span(now - Date.parse(s.fetchedAt))} old${retry}`);
		if (s.hint) lines.push(s.hint);
	}
	return lines.join("\n");
}

function renderUpdate(s: UpdateStatus): string {
	if (s.error) return `burnbar: ${s.error}${s.hint ? `\n${s.hint}` : ""}`;
	if (s.installed) return `Updated to ${s.installed}. Restart Plasma or log in again to load the new widget.`;
	if (s.available) return `burnbar ${s.latest} is available (${s.page}). Run \`burnbar update\` to install it.`;
	return `burnbar ${s.current} is up to date.`;
}

const { values, positionals } = parseArgs({
	allowPositionals: true,
	options: {
		json: { type: "boolean", default: false },
		check: { type: "boolean", default: false },
		"max-age": { type: "string" },
		"config-dir": { type: "string" },
		help: { type: "boolean", short: "h", default: false },
	},
});

const maxAge = Number(values["max-age"] ?? Number.NaN);

function print(result: object, text: string, failed: boolean) {
	console.log(values.json ? JSON.stringify(result) : text);
	if (failed) process.exitCode = 1;
}

if (values.help) {
	console.log(HELP);
} else if (positionals[0] === "update") {
	const result = values.check ? await checkUpdate(Number.isFinite(maxAge) ? maxAge : undefined) : await installUpdate();
	print(result, renderUpdate(result), !!result.error);
} else if (positionals.length) {
	console.error(`burnbar: unknown command ${positionals[0]}\n\n${HELP}`);
	process.exitCode = 2;
} else {
	const result = await readUsage(Number.isFinite(maxAge) ? maxAge : 60, claudeDir(values["config-dir"]));
	print(result, renderUsage(result), !result.ok);
}
