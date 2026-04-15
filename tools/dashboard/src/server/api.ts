import { API_PORT } from '../config';
import { healthCheck, listMetrics, handleQuery } from './routes';

export function startApiServer(): ReturnType<typeof Bun.serve> {
  const server = Bun.serve({
    port: API_PORT,
    hostname: '0.0.0.0',
    routes: {
      '/': {
        GET: () => healthCheck(),
      },
      '/metrics': {
        POST: () => listMetrics(),
      },
    },
    async fetch(req) {
      const url = new URL(req.url);

      // Handle /query POST
      if (url.pathname === '/query' && req.method === 'POST') {
        return handleQuery(req);
      }

      // CORS preflight
      if (req.method === 'OPTIONS') {
        return new Response(null, {
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
          },
        });
      }

      return new Response('Not Found', { status: 404 });
    },
  });

  return server;
}
