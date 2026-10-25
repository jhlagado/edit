// Set the screen configuration block in an EDIT.COM image.
//
//   node tools/configure.mjs EDIT.COM [--columns N] [--rows N]
//        [--probe on|off] [--output OUT.COM]
//
// Without an option the current configuration is printed. The block layout is
// defined in docs/specification.md.

import { readFile, writeFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

export const CONFIG_OFFSET = 0x0003;
export const CONFIG_TAG = "ECFG";
export const CONFIG_VERSION = 1;
export const CONFIG_PROBE = 1;
export const MINIMUM_COLUMNS = 20;
export const MAXIMUM_COLUMNS = 80;
export const MINIMUM_ROWS = 4;
export const MAXIMUM_ROWS = 24;

function checkTag(image) {
  const tag = Buffer.from(
    image.slice(CONFIG_OFFSET, CONFIG_OFFSET + CONFIG_TAG.length),
  ).toString("ascii");
  if (
    tag !== CONFIG_TAG ||
    image[CONFIG_OFFSET + CONFIG_TAG.length] !== CONFIG_VERSION
  ) {
    throw new Error("image has no Edit configuration block, version 1");
  }
}

export function readConfiguration(image) {
  checkTag(image);
  const base = CONFIG_OFFSET + CONFIG_TAG.length + 1;
  return {
    columns: image[base],
    rows: image[base + 1],
    probe: (image[base + 2] & CONFIG_PROBE) !== 0,
  };
}

function checkSize(name, value, minimum, maximum) {
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new Error(`${name} must be an integer from ${minimum} to ${maximum}`);
  }
}

// Return a copy of the image with the given fields replaced.
export function configureImage(image, { columns, rows, probe } = {}) {
  checkTag(image);
  const next = Uint8Array.from(image);
  const base = CONFIG_OFFSET + CONFIG_TAG.length + 1;
  if (columns !== undefined) {
    checkSize("columns", columns, MINIMUM_COLUMNS, MAXIMUM_COLUMNS);
    next[base] = columns;
  }
  if (rows !== undefined) {
    checkSize("rows", rows, MINIMUM_ROWS, MAXIMUM_ROWS);
    next[base + 1] = rows;
  }
  if (probe !== undefined) {
    next[base + 2] = probe
      ? next[base + 2] | CONFIG_PROBE
      : next[base + 2] & ~CONFIG_PROBE;
  }
  return next;
}

function parseArguments(argv) {
  const [input, ...rest] = argv;
  if (input === undefined) throw new Error("missing EDIT.COM path");
  const options = {};
  let output = input;
  for (let index = 0; index < rest.length; index += 2) {
    const [name, value] = [rest[index], rest[index + 1]];
    if (value === undefined) throw new Error(`${name} needs a value`);
    if (name === "--columns") options.columns = Number(value);
    else if (name === "--rows") options.rows = Number(value);
    else if (name === "--probe") {
      if (value !== "on" && value !== "off") {
        throw new Error("--probe must be on or off");
      }
      options.probe = value === "on";
    } else if (name === "--output") output = value;
    else throw new Error(`unknown option ${name}`);
  }
  return { input, output, options };
}

async function main(argv) {
  const { input, output, options } = parseArguments(argv);
  const image = new Uint8Array(await readFile(input));
  if (Object.keys(options).length === 0 && output === input) {
    console.log(JSON.stringify(readConfiguration(image)));
    return;
  }
  const next = configureImage(image, options);
  await writeFile(output, next);
  console.log(`${output}: ${JSON.stringify(readConfiguration(next))}`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
