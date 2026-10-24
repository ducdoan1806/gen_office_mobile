export type AiEntry = { id: string; label: string; text: string };
export type AiChange = { id: string; before: string; after: string };
/** Holds one proposal scope. Never executes model supplied code or positions. */
export class AiEditGuard {
  private captured?: { revision: string; fingerprint: string; entries: AiEntry[] };
  capture(fingerprint: string, entries: AiEntry[], scope: string) {
    if (!entries.length) throw Error('Không có nội dung có thể sửa trong vùng này.');
    if (entries.length > 500 || JSON.stringify(entries).length > 60000) throw Error('Vùng quá lớn. Hãy chọn vùng nhỏ hơn (tối đa 500 đoạn/ô, 60.000 ký tự).');
    this.captured = { revision: crypto.randomUUID(), fingerprint, entries: structuredClone(entries) };
    return { revision: this.captured.revision, scope, entries };
  }
  validate(args: any, fingerprint: string): AiChange[] {
    const c = this.captured;
    if (!c || args?.revision !== c.revision || fingerprint !== c.fingerprint) throw Error('Tài liệu đã thay đổi. Gửi yêu cầu mới để lấy nội dung hiện tại.');
    if (!Array.isArray(args.changes) || !args.changes.length || args.changes.length > 500) throw Error('Danh sách thay đổi không hợp lệ.');
    const seen = new Set<string>();
    let size = 0;
    for (const op of args.changes) {
      const entry = c.entries.find(e => e.id === op?.id);
      if (!entry || seen.has(op.id) || op.before !== entry.text || typeof op.after !== 'string' || op.after.includes('\u0000') || op.after.length > 20000) throw Error('Thay đổi không khớp nội dung đã gửi.');
      seen.add(op.id); size += op.after.length;
    }
    if (size > 100000) throw Error('Kết quả vượt giới hạn chỉnh sửa.');
    return args.changes;
  }
  invalidate() { this.captured = undefined; }
}
