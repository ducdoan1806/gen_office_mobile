export const join = (...parts: string[]) => parts.join('/').replace(/\/+/g, '/');
export const dirname = (s: string) => s.slice(0, s.lastIndexOf('/')) || '.';
export const basename = (s: string) => s.slice(s.lastIndexOf('/') + 1);
export const extname = (s: string) => { const b = basename(s); return b.includes('.') ? b.slice(b.lastIndexOf('.')) : ''; };
