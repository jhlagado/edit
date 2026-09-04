import { mkdtemp, readFile, rm } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { tmpdir } from "node:os";

import {
  assembleLegacySourceWithAtomArtifacts,
  symbolsFromDebugMap,
} from "../../tools/atom-assembly.mjs";

function externNames(source) {
  return [...source.matchAll(/^\s*extern\s+([A-Za-z_][A-Za-z0-9_]*)\b/gim)].map(
    (match) => match[1],
  );
}

export async function assembleEditorCandidate({
  name,
  source,
  interfaceSource,
  interfaceSources = interfaceSource === undefined ? [] : [interfaceSource],
  includeRoots = [dirname(source)],
}) {
  const sourceText = await readFile(source, "utf8");
  const externalSymbols = (
    await Promise.all(
      interfaceSources.map(async (interfacePath) =>
        externNames(await readFile(interfacePath, "utf8")),
      ),
    )
  ).flat();
  const temporaryDirectory = await mkdtemp(
    join(tmpdir(), "edit-candidate-"),
  );
  let atomArtifacts;
  try {
    atomArtifacts = await assembleLegacySourceWithAtomArtifacts({
      temporaryDirectory,
      sourceDirectory: dirname(source),
      name: `${name}.asm`,
      source: sourceText,
      expectedBytes: undefined,
      base: 0x0100,
      entryAddress: 0x0100,
      includeRoots: includeRoots.map((root) => resolve(root)),
      externalSymbols,
    });
  } finally {
    await rm(temporaryDirectory, { recursive: true, force: true });
  }

  return Object.freeze({
    bytes: atomArtifacts.bytes,
    name,
    symbols: symbolsFromDebugMap(atomArtifacts.debugMap),
  });
}
