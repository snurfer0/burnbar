import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { rm, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import metadata from "../plasmoid/metadata.json";
import { describe, Failure, type Problem } from "./failure";
import { CACHE_DIR, readText, writeText } from "./files";

export const VERSION = metadata.KPlugin.Version;

const RELEASES = "https://api.github.com/repos/snurfer0/burnbar/releases/latest";
const CACHE = join(CACHE_DIR, "update.json");
export const CHECK_EVERY_SECONDS = 86_400;

type Release = { version: string; page: string; asset: { url: string; digest: string | null } | null };

type Cached = { checkedAt: string; release: Release | null };

export type UpdateStatus = {
	/** The version on disk, which the widget compares with the version it was loaded as. */
	current: string;
	latest: string | null;
	available: boolean;
	/** The release page, for the notes. */
	page: string | null;
	checkedAt: string | null;
	/** Set by an install: the version that is now on disk. */
	installed: string | null;
	error: string | null;
	hint: string | null;
};

/** Numeric comparison of dotted versions: "0.10.0" is newer than "0.9.1". */
export function newer(candidate: string, than: string): boolean {
	const a = candidate.split(".").map(Number);
	const b = than.split(".").map(Number);
	for (let index = 0; index < Math.max(a.length, b.length); index++) {
		const difference = (a[index] ?? 0) - (b[index] ?? 0);
		if (difference) return difference > 0;
	}
	return false;
}

async function fetchRelease(): Promise<Release | null> {
	const headers = { Accept: "application/vnd.github+json", "User-Agent": `burnbar/${VERSION}` };
	const response = await fetch(RELEASES, { headers, signal: AbortSignal.timeout(15_000) }).catch(() => {
		throw new Failure("Cannot reach GitHub", "No answer from api.github.com. Burnbar looks for updates again later.");
	});
	if (response.status === 404) return null;
	if (!response.ok)
		throw new Failure(
			`GitHub answered HTTP ${response.status}`,
			"The update check failed. Burnbar looks for updates again later.",
		);
	const body = (await response.json()) as {
		tag_name?: string;
		html_url?: string;
		assets?: { name?: string; browser_download_url?: string; digest?: string | null }[];
	};
	const asset = body.assets?.find((candidate) => candidate.name?.endsWith(".plasmoid"));
	return {
		version: (body.tag_name ?? "").replace(/^v/, ""),
		page: body.html_url ?? "",
		asset: asset?.browser_download_url ? { url: asset.browser_download_url, digest: asset.digest ?? null } : null,
	};
}

function status(cached: Cached | null, problem: Problem | null = null): UpdateStatus {
	const release = cached?.release ?? null;
	return {
		current: VERSION,
		latest: release?.version ?? null,
		available: !!release && newer(release.version, VERSION),
		page: release?.page ?? null,
		checkedAt: cached?.checkedAt ?? null,
		installed: null,
		error: problem?.message ?? null,
		hint: problem?.hint ?? null,
	};
}

async function readCached(): Promise<Cached | null> {
	try {
		return JSON.parse((await readText(CACHE)) ?? "") as Cached;
	} catch {
		return null;
	}
}

/** What GitHub says the latest release is; asked at most once per `maxAge` seconds. */
export async function checkUpdate(maxAge = CHECK_EVERY_SECONDS): Promise<UpdateStatus> {
	const cached = await readCached();
	const age = cached ? (Date.now() - Date.parse(cached.checkedAt)) / 1000 : Number.POSITIVE_INFINITY;
	if (cached && age < maxAge) return status(cached);
	try {
		const fresh = { checkedAt: new Date().toISOString(), release: await fetchRelease() };
		await writeText(CACHE, JSON.stringify(fresh));
		return status(fresh);
	} catch (error) {
		// A failed check still counts as one, so an offline machine does not ask on every call.
		const failed = { checkedAt: new Date().toISOString(), release: cached?.release ?? null };
		await writeText(CACHE, JSON.stringify(failed)).catch(() => {});
		return status(failed, describe(error));
	}
}

/**
 * The widget folder this bundle runs from, when it is a copy installed for this user.
 * Running from source, or from a copy a package manager installed system-wide, returns null.
 */
function installedWidget(): string | null {
	const root = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
	const plasmoids = join(process.env.XDG_DATA_HOME || join(homedir(), ".local", "share"), "plasma", "plasmoids");
	return dirname(root) === plasmoids ? root : null;
}

/** Downloads the latest release and installs it over this widget with kpackagetool6. */
export async function installUpdate(): Promise<UpdateStatus> {
	const checked = await checkUpdate(0);
	if (!checked.available || checked.error) return checked;
	try {
		if (!installedWidget())
			throw new Failure(
				"This copy of burnbar cannot update itself",
				"It runs from a source folder or was installed system-wide. Update it the way it was installed: git pull and ./install.sh, or the package manager.",
			);
		const release = (await readCached())?.release;
		if (!release?.asset) throw new Failure("The release has no .plasmoid file", "Download it from the release page.");
		const download = await fetch(release.asset.url, { signal: AbortSignal.timeout(60_000) });
		if (!download.ok) throw new Failure(`Download failed with HTTP ${download.status}`, "Try again later.");
		const bytes = Buffer.from(await download.arrayBuffer());
		const digest = `sha256:${createHash("sha256").update(bytes).digest("hex")}`;
		if (release.asset.digest && release.asset.digest !== digest)
			throw new Failure("The download is damaged", "Its checksum does not match the release. Nothing was installed.");
		const file = join(CACHE_DIR, `burnbar-${release.version}.plasmoid`);
		await writeFile(file, bytes);
		try {
			await promisify(execFile)("kpackagetool6", ["-t", "Plasma/Applet", "-u", file]);
		} catch {
			throw new Failure("kpackagetool6 could not install the update", `Install ${file} by hand to see why.`);
		}
		await rm(file, { force: true });
		return { ...checked, installed: release.version };
	} catch (error) {
		const problem = describe(error);
		return { ...checked, error: problem.message, hint: problem.hint };
	}
}
