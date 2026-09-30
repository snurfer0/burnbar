/**
 * A failure the user can do something about, or at least should understand:
 * a short message for the panel, and a hint that says what it means and what happens next.
 */
export class Failure extends Error {
	constructor(
		message: string,
		readonly hint: string,
		/** Set when no request may be made before this time (unix milliseconds). */
		readonly retryAt: number | null = null,
		readonly backoffSeconds = 0,
	) {
		super(message);
	}
}

export type Problem = { message: string; hint: string | null; retryAt: number | null; backoffSeconds: number };

/** Any thrown value as a Problem; only a Failure carries a hint and a back-off. */
export function describe(error: unknown): Problem {
	const known = error instanceof Failure;
	return {
		message: error instanceof Error ? error.message : String(error),
		hint: known ? error.hint : null,
		retryAt: known ? error.retryAt : null,
		backoffSeconds: known ? error.backoffSeconds : 0,
	};
}

export const loginExpired = () =>
	new Failure(
		"Claude Code login expired",
		"Claude Code's login token has run out. It renews the next time you use Claude Code; burnbar never renews it itself. Until then the last reading is shown.",
	);
