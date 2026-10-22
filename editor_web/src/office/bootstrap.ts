import { Buffer } from 'buffer';
(globalThis as any).Buffer = Buffer;
await import('./main');
