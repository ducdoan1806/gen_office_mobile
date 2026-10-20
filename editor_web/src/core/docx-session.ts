import { parseDocx } from '../../vendor/docx-engine/src/parse';
import { saveDocx, type ParsedDocFull, type SaveBlock } from '../../vendor/docx-engine/src/patch';
import { patchParagraphTexts } from '../../vendor/docx-engine/src/text-patch';
import type { DocumentFile } from '../platform/document-storage';

export interface ParagraphView { id: number; text: string; editable: boolean; type: string }
// Only plain w:p/w:r/w:t paragraphs are editable initially. Preserve every
// unsupported field, link, drawing, revision, table and content control verbatim.
const allowed = new Set(['w:p','w:pPr','w:pStyle','w:jc','w:spacing','w:ind','w:r','w:rPr','w:rStyle','w:rFonts','w:b','w:i','w:u','w:sz','w:szCs','w:color','w:lang','w:t']);
export class DocxSession {
  private edits = new Map<number, string>();
  private constructor(readonly name: string, private parsed: ParsedDocFull) {}
  static async open(file: DocumentFile): Promise<DocxSession> {
    const parsed = await parseDocx(file.bytes, {expandAltChunks: false});
    return new DocxSession(file.name, parsed);
  }
  get dirty(): boolean { return this.edits.size > 0; }
  get paragraphs(): ParagraphView[] {
    return this.parsed.blocks.filter(b => !b.hidden).map((b, index) => {
      const xml = b.originalXml ?? '';
      const tags = Array.from(xml.matchAll(/<\/?([\w:.-]+)/g), m => m[1]);
      const plain = ['paragraph','heading','listItem'].includes(b.type)
        && /^<w:p[\s>]/.test(xml) && tags.every(tag => allowed.has(tag));
      // XML extraction is intentionally tied to the same text nodes used by
      // upstream surgical patching, avoiding display-text/field mismatches.
      const text = Array.from(xml.matchAll(/<w:t(?:\s[^>]*)?>([\s\S]*?)<\/w:t>/g), m => decode(m[1])).join('');
      const editable = plain && /<w:t[\s>]/.test(xml)
        && !this.parsed.protection?.enforced;
      return {id: index, text: this.edits.get(index) ?? text, editable, type: b.type};
    });
  }
  setText(id: number, text: string): void {
    const view = this.paragraphs.find(p => p.id === id);
    if (!view?.editable) throw new Error('Đoạn này chưa hỗ trợ chỉnh sửa.');
    if (/[\r\n\t\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(text)) throw new Error('Chưa hỗ trợ chèn dòng, tab hoặc ký tự điều khiển.');
    const blocks = this.parsed.blocks.filter(b => !b.hidden);
    const patched = patchParagraphTexts(blocks[id].originalXml!, text);
    if (patched === null) throw new Error('Không thể sửa đoạn mà vẫn bảo toàn cấu trúc XML.');
    if (patched === blocks[id].originalXml) this.edits.delete(id);
    else this.edits.set(id, text);
  }
  reset(): void { this.edits.clear(); }
  async export(): Promise<DocumentFile> {
    const blocks: SaveBlock[] = this.parsed.blocks.filter(b => !b.hidden).map((block, id) => {
      if (block.docxIndex === null) throw new Error('Block không có neo DOCX.');
      const text = this.edits.get(id);
      if (text === undefined) return {kind: 'original', docxIndex: block.docxIndex};
      const xml = patchParagraphTexts(block.originalXml!, text);
      if (xml === null) throw new Error('Không thể tạo bản vá DOCX.');
      return {kind: 'xml', xml, docxIndex: block.docxIndex};
    });
    return {name: this.name, bytes: await saveDocx(this.parsed, blocks)};
  }
}
function decode(text: string): string {
  return text.replace(/&(#x[0-9a-f]+|#\d+|amp|lt|gt|quot|apos);/gi, (match, entity: string) => {
    const named: Record<string,string> = {amp:'&',lt:'<',gt:'>',quot:'"',apos:"'"};
    if (entity.startsWith('#x')) return String.fromCodePoint(parseInt(entity.slice(2),16));
    if (entity.startsWith('#')) return String.fromCodePoint(parseInt(entity.slice(1),10));
    return named[entity] ?? match;
  });
}
