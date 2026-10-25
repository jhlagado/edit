// Strict character-cell terminal of any size for the editor's terminal subset,
// plus the character and line insert and delete the editor sends to TEC-OS's
// console.
// It follows the deferred-wrap model of a VT100 and records every operation
// that a correct full-screen repaint never needs: scrolling, wrapping onto a
// new line, and cursor addresses outside the screen.

export const ATTR_REVERSE = 1 << 2;

export function createScreenTerminal({ columns, rows }) {
  const count = columns * rows;
  const cells = new Uint8Array(count);
  const attributes = new Uint8Array(count);
  const faults = [];
  let cursorRow = 0;
  let cursorColumn = 0;
  let reverse = false;
  let wrapPending = false;
  let bellCount = 0;
  let state = "ground";
  let parameters = "";

  const clear = (from, to) => {
    cells.fill(0x20, from, to);
    attributes.fill(0, from, to);
  };

  const lineFeed = () => {
    if (cursorRow === rows - 1) {
      faults.push("scroll");
      cells.copyWithin(0, columns);
      attributes.copyWithin(0, columns);
      clear(count - columns, count);
    } else {
      cursorRow += 1;
    }
  };

  const printable = (byte) => {
    if (wrapPending) {
      faults.push(`wrap at row ${cursorRow + 1}`);
      cursorColumn = 0;
      lineFeed();
      wrapPending = false;
    }
    const index = cursorRow * columns + cursorColumn;
    cells[index] = byte;
    attributes[index] = reverse ? ATTR_REVERSE : 0;
    if (cursorColumn === columns - 1) wrapPending = true;
    else cursorColumn += 1;
  };

  const csi = (final) => {
    const values = parameters === "" ? [] : parameters.split(";").map(Number);
    wrapPending = false;
    if (final === 0x48) {
      const row = values[0] || 1;
      const column = values[1] || 1;
      if (row > rows || column > columns) {
        faults.push(`position ${row};${column}`);
      }
      cursorRow = Math.min(row, rows) - 1;
      cursorColumn = Math.min(column, columns) - 1;
    } else if (final === 0x4a && values[0] === 2) {
      clear(0, count);
    } else if (final === 0x4b && (values[0] ?? 0) === 0) {
      clear(cursorRow * columns + cursorColumn, (cursorRow + 1) * columns);
    } else if (final === 0x40 || final === 0x50) {
      // Insert (@) or delete (P) characters at the cursor, as TEC-OS's video
      // console does: the rest of the line moves, and blanks are plain.
      const start = cursorRow * columns + cursorColumn;
      const end = (cursorRow + 1) * columns;
      const n = Math.min(values[0] || 1, end - start);
      if (final === 0x40) {
        cells.copyWithin(start + n, start, end - n);
        attributes.copyWithin(start + n, start, end - n);
        clear(start, start + n);
      } else {
        cells.copyWithin(start, start + n, end);
        attributes.copyWithin(start, start + n, end);
        clear(end - n, end);
      }
    } else if (final === 0x4c || final === 0x4d) {
      // Insert (L) or delete (M) lines at the cursor row, as TEC-OS's video
      // console does: the rows below move, and the cursor goes to column 1.
      const start = cursorRow * columns;
      const n = Math.min(values[0] || 1, rows - cursorRow) * columns;
      if (final === 0x4c) {
        cells.copyWithin(start + n, start, count - n);
        attributes.copyWithin(start + n, start, count - n);
        clear(start, start + n);
      } else {
        cells.copyWithin(start, start + n, count);
        attributes.copyWithin(start, start + n, count);
        clear(count - n, count);
      }
      cursorColumn = 0;
    } else if (final === 0x6d) {
      for (const value of values.length === 0 ? [0] : values) {
        if (value === 0) reverse = false;
        else if (value === 7) reverse = true;
        else faults.push(`rendition ${value}`);
      }
    } else {
      faults.push(`csi ${parameters}${String.fromCharCode(final)}`);
    }
  };

  const writeOutput = (value) => {
    const byte = value & 0xff;
    if (state === "escape") {
      state = byte === 0x5b ? "csi" : "ground";
      parameters = "";
      if (byte !== 0x5b) faults.push(`escape ${byte}`);
      return;
    }
    if (state === "csi") {
      if ((byte >= 0x30 && byte <= 0x39) || byte === 0x3b) {
        parameters += String.fromCharCode(byte);
        return;
      }
      state = "ground";
      csi(byte);
      return;
    }
    if (byte >= 0x20 && byte <= 0x7e) printable(byte);
    else if (byte === 0x1b) state = "escape";
    else if (byte === 0x07) bellCount += 1;
    else if (byte === 0x0d) {
      wrapPending = false;
      cursorColumn = 0;
    } else if (byte === 0x0a) {
      wrapPending = false;
      lineFeed();
    } else faults.push(`control ${byte}`);
  };

  const reset = () => {
    clear(0, count);
    faults.length = 0;
    cursorRow = 0;
    cursorColumn = 0;
    reverse = false;
    wrapPending = false;
    bellCount = 0;
    state = "ground";
    parameters = "";
  };

  const snapshot = () => ({
    columns,
    rows,
    cells: cells.slice(),
    attributes: attributes.slice(),
    cursorRow,
    cursorColumn,
    bellCount,
    faults: [...faults],
  });

  const row = (index) =>
    Buffer.from(cells.slice(index * columns, (index + 1) * columns)).toString(
      "ascii",
    );

  reset();
  return { writeOutput, reset, snapshot, row };
}
