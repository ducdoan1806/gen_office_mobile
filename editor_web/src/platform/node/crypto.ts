import { sha256 } from '@noble/hashes/sha2.js';
import { Buffer } from 'buffer';
export function createHash(name: string) { if (name !== 'sha256')
    throw Error(`Unsupported hash: ${name}`); const hash = sha256.create(); return { update(value: any) { hash.update(typeof value === 'string' ? new TextEncoder().encode(value) : value); return this; }, digest(encoding?: string) { const bytes = Buffer.from(hash.digest()); return encoding ? bytes.toString(encoding as any) : bytes; } }; }
export const randomUUID = () => globalThis.crypto.randomUUID();
