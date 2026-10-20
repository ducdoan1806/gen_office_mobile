/** Browser-compatible one-shot byte handoff; also accepts host-provided URLs. */
export async function fetchDocBytes(url: string): Promise<Uint8Array> {
 try { const res = await fetch(url); if (!res.ok) throw new Error(`document bytes unavailable (${res.status})`); return new Uint8Array(await res.arrayBuffer()); }
 finally { if (url.startsWith('blob:')) URL.revokeObjectURL(url); }
}
