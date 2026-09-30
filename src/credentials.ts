import { join } from "node:path";
import { Failure } from "./failure";
import { readText } from "./files";

export type Credentials = {
	accessToken: string;
	expiresAt: number;
	plan: string;
};

// burnbar only reads the token. Refreshing it here would rotate the refresh token
// under a running Claude Code and log it out, so an expired token is reported, not fixed.
export async function readCredentials(claudeDir: string): Promise<Credentials> {
	const file = join(claudeDir, ".credentials.json");
	const text = await readText(file);
	if (text === null)
		throw new Failure(
			"Not signed in to Claude Code",
			`There is no login in ${claudeDir}. Run \`claude\` in a terminal and sign in. If Claude Code uses another folder (CLAUDE_CONFIG_DIR), set it as the Claude folder in the settings.`,
		);
	let oauth: { accessToken?: string; expiresAt?: number; subscriptionType?: string; rateLimitTier?: string };
	try {
		oauth = JSON.parse(text)?.claudeAiOauth ?? {};
	} catch {
		throw new Failure("Cannot read the Claude Code login", `${file} is not valid JSON. Sign in again with \`claude\`.`);
	}
	if (!oauth.accessToken)
		throw new Failure(
			"No Claude subscription login",
			"Claude Code is not signed in with a Claude subscription here. Usage limits exist only for a subscription: run `claude` and sign in with one.",
		);
	return {
		accessToken: oauth.accessToken,
		expiresAt: oauth.expiresAt ?? Number.POSITIVE_INFINITY,
		plan: planName(oauth.subscriptionType, oauth.rateLimitTier),
	};
}

// "max" + "default_claude_max_5x" -> "Max 5x"
export function planName(subscription?: string, tier?: string): string {
	if (!subscription) return "";
	const name = subscription.charAt(0).toUpperCase() + subscription.slice(1);
	const multiplier = tier?.match(/_(\d+x)$/)?.[1];
	return multiplier ? `${name} ${multiplier}` : name;
}
