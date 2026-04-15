import { createHash } from 'node:crypto';

function normalizeBody(text: string): string {
  return text.trim().toLowerCase().replace(/\s+/g, ' ').slice(0, 8_000);
}

export function canonicalKey(
  cwd: string,
  epistemicClass: string,
  body: string,
): string {
  const normCwd = cwd.trim();
  const normBody = normalizeBody(body);
  const h = createHash('sha256');
  h.update(`${normCwd}\0${epistemicClass}\0${normBody}`);
  return h.digest('hex');
}

export function randomId(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = [...bytes].map((b) => b.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
