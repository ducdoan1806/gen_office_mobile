export function address(value: string): {
    row: number;
    col: number;
} {
    const match = /^\$?([A-Z]{1,3})\$?([1-9][0-9]{0,6})$/i.exec(value.trim());
    if (!match)
        throw Error('Địa chỉ ô không hợp lệ.');
    let col = 0;
    for (const letter of match[1].toUpperCase())
        col = col * 26 + letter.charCodeAt(0) - 64;
    const row = Number(match[2]);
    if (col > 16384 || row > 1048576)
        throw Error('Địa chỉ vượt giới hạn bảng tính.');
    return { row, col };
}
export function columnName(col: number): string { let text = ''; for (; col > 0; col = Math.floor((col - 1) / 26))
    text = String.fromCharCode(65 + (col - 1) % 26) + text; return text; }
