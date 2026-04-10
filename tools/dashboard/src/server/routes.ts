import { EVENTS_LOG, COSTS_LOG } from "../config";
import { readJsonl } from "./jsonl-reader";

interface QueryTarget {
	target: string;
	type?: string;
}

interface QueryRequest {
	targets: QueryTarget[];
	range?: {
		from: string;
		to: string;
	};
}

const METRICS = [
	"events",
	"events_by_type",
	"costs",
	"cost_by_model",
	"sessions",
	"tool_usage",
];

export function healthCheck(): Response {
	return new Response("OK", { status: 200 });
}

export function listMetrics(): Response {
	return Response.json(METRICS);
}

export async function handleQuery(req: Request): Promise<Response> {
	const body = (await req.json()) as QueryRequest;
	const { targets, range } = body;
	const from = range?.from;
	const to = range?.to;

	const results: unknown[] = [];

	for (const target of targets) {
		switch (target.target) {
			case "events":
				results.push(await queryEvents(from, to));
				break;
			case "events_by_type":
				results.push(await queryEventsByType(from, to));
				break;
			case "costs":
				results.push(await queryCosts(from, to));
				break;
			case "cost_by_model":
				results.push(await queryCostByModel(from, to));
				break;
			case "sessions":
				results.push(await querySessions(from, to));
				break;
			case "tool_usage":
				results.push(await queryToolUsage(from, to));
				break;
			default:
				results.push({ target: target.target, datapoints: [] });
		}
	}

	return Response.json(results);
}

async function queryEvents(from?: string, to?: string) {
	const events = await readJsonl(EVENTS_LOG, { from, to });
	return {
		target: "events",
		type: "table",
		columns: [
			{ text: "timestamp", type: "time" },
			{ text: "session_id", type: "string" },
			{ text: "event_type", type: "string" },
		],
		rows: events.map((e) => [e.timestamp, e.session_id, e.event_type]),
	};
}

async function queryEventsByType(from?: string, to?: string) {
	const events = await readJsonl(EVENTS_LOG, { from, to });
	const counts: Record<string, number> = {};
	for (const e of events) {
		const type = (e.event_type as string) ?? "unknown";
		counts[type] = (counts[type] ?? 0) + 1;
	}

	return {
		target: "events_by_type",
		type: "table",
		columns: [
			{ text: "event_type", type: "string" },
			{ text: "count", type: "number" },
		],
		rows: Object.entries(counts).sort((a, b) => b[1] - a[1]),
	};
}

async function queryCosts(from?: string, to?: string) {
	const costs = await readJsonl(COSTS_LOG, { from, to });
	return {
		target: "costs",
		type: "table",
		columns: [
			{ text: "timestamp", type: "time" },
			{ text: "session_id", type: "string" },
			{ text: "model", type: "string" },
			{ text: "input_tokens", type: "number" },
			{ text: "output_tokens", type: "number" },
			{ text: "cache_read_tokens", type: "number" },
			{ text: "cache_creation_tokens", type: "number" },
			{ text: "estimated_cost_usd", type: "number" },
		],
		rows: costs.map((c) => [
			c.timestamp,
			c.session_id,
			c.model,
			c.input_tokens,
			c.output_tokens,
			c.cache_read_tokens,
			c.cache_creation_tokens,
			c.estimated_cost_usd,
		]),
	};
}

async function queryCostByModel(from?: string, to?: string) {
	const costs = await readJsonl(COSTS_LOG, { from, to });
	const byModel: Record<string, { cost: number; sessions: Set<string> }> = {};

	for (const c of costs) {
		const model = (c.model as string) ?? "unknown";
		if (!byModel[model]) byModel[model] = { cost: 0, sessions: new Set() };
		byModel[model].cost += (c.estimated_cost_usd as number) ?? 0;
		byModel[model].sessions.add((c.session_id as string) ?? "");
	}

	return {
		target: "cost_by_model",
		type: "table",
		columns: [
			{ text: "model", type: "string" },
			{ text: "total_cost_usd", type: "number" },
			{ text: "session_count", type: "number" },
		],
		rows: Object.entries(byModel)
			.map(([model, data]) => [
				model,
				Math.round(data.cost * 1000000) / 1000000,
				data.sessions.size,
			])
			.sort((a, b) => (b[1] as number) - (a[1] as number)),
	};
}

async function querySessions(from?: string, to?: string) {
	const events = await readJsonl(EVENTS_LOG, {
		from,
		to,
		eventType: "session_start",
	});
	return {
		target: "sessions",
		type: "table",
		columns: [
			{ text: "timestamp", type: "time" },
			{ text: "session_id", type: "string" },
		],
		rows: events.map((e) => [e.timestamp, e.session_id]),
	};
}

async function queryToolUsage(from?: string, to?: string) {
	const events = await readJsonl(EVENTS_LOG, { from, to });
	const toolEvents = events.filter(
		(e) => e.event_type === "file_read" || e.event_type === "skill_invoked",
	);

	return {
		target: "tool_usage",
		type: "table",
		columns: [
			{ text: "timestamp", type: "time" },
			{ text: "event_type", type: "string" },
			{ text: "detail", type: "string" },
		],
		rows: toolEvents.map((e) => {
			const payload = e.payload as Record<string, unknown> | undefined;
			const detail =
				e.event_type === "file_read"
					? ((payload?.file as string) ?? "")
					: ((payload?.skill as string) ?? "");
			return [e.timestamp, e.event_type, detail];
		}),
	};
}
