import { describe, expect, test } from "bun:test";
import {
	hoursBetween,
	daysBetween,
	classDecayFactor,
	questionUrgencyMultiplier,
	contradictionFactor,
	confidenceToBase,
	effectiveScore,
} from "./scoring";
import { defaultLoreConfig } from "./config";

const cfg = defaultLoreConfig();
const decay = cfg;

describe("hoursBetween", () => {
	test("non-negative delta", () => {
		expect(hoursBetween("2026-01-01T00:00:00Z", "2026-01-02T00:00:00Z")).toBe(
			24,
		);
	});
	test("reversed order clamps to 0", () => {
		expect(hoursBetween("2026-01-02T00:00:00Z", "2026-01-01T00:00:00Z")).toBe(
			0,
		);
	});
});

describe("daysBetween", () => {
	test("one day", () => {
		expect(daysBetween("2026-01-01T00:00:00Z", "2026-01-02T00:00:00Z")).toBe(1);
	});
});

describe("classDecayFactor", () => {
	test("HYPOTHESIS decays faster than DECISION over same horizon", () => {
		const t0 = "2026-01-01T00:00:00Z";
		const t1 = "2026-01-15T00:00:00Z";
		const dDec = classDecayFactor("DECISION", t0, t1, decay);
		const dHyp = classDecayFactor("HYPOTHESIS", t0, t1, decay);
		expect(dHyp).toBeLessThan(dDec);
	});
});

describe("questionUrgencyMultiplier", () => {
	test("grows with sessions_unresolved and age", () => {
		const t0 = "2026-01-01T00:00:00Z";
		const t1 = "2026-01-08T00:00:00Z";
		const low = questionUrgencyMultiplier(0, t0, t1, decay);
		const high = questionUrgencyMultiplier(5, t0, t1, decay);
		expect(high).toBeGreaterThan(low);
	});
});

describe("contradictionFactor", () => {
	test("applies negative weight with floor", () => {
		const f = contradictionFactor(-0.6, decay);
		expect(f).toBeCloseTo(0.4, 5);
		expect(contradictionFactor(-5, decay)).toBe(
			decay.contradiction_score_floor,
		);
	});
});

describe("confidenceToBase", () => {
	test("QUESTION uses priority", () => {
		expect(confidenceToBase(null, "high", "QUESTION")).toBeGreaterThan(
			confidenceToBase(null, "low", "QUESTION"),
		);
	});
});

describe("effectiveScore", () => {
	test("QUESTION rises with unresolved count", () => {
		const now = "2026-01-10T12:00:00Z";
		const first = "2026-01-01T00:00:00Z";
		const low = effectiveScore(
			{
				epistemic_class: "QUESTION",
				first_seen_at: first,
				last_seen_at: first,
				base_score: 0.65,
				sessions_unresolved: 0,
			},
			now,
			0,
			decay,
		);
		const high = effectiveScore(
			{
				epistemic_class: "QUESTION",
				first_seen_at: first,
				last_seen_at: first,
				base_score: 0.65,
				sessions_unresolved: 5,
			},
			now,
			0,
			decay,
		);
		expect(high).toBeGreaterThan(low);
	});

	test("DECISION suppressed by contradiction weights on target", () => {
		const now = "2026-01-05T00:00:00Z";
		const first = "2026-01-01T00:00:00Z";
		const plain = effectiveScore(
			{
				epistemic_class: "DECISION",
				first_seen_at: first,
				last_seen_at: first,
				base_score: 1,
				sessions_unresolved: 0,
			},
			now,
			0,
			decay,
		);
		const hit = effectiveScore(
			{
				epistemic_class: "DECISION",
				first_seen_at: first,
				last_seen_at: first,
				base_score: 1,
				sessions_unresolved: 0,
			},
			now,
			-0.6,
			decay,
		);
		expect(hit).toBeLessThan(plain);
	});
});
