import { createHash } from "node:crypto";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import {
  assembleProjectOwnedAtomArtifacts,
  projectOwnedCandidates,
} from "./atom-assembly.mjs";

const temporaryDirectory = await mkdtemp(join(tmpdir(), "edit-build-"));
try {
  const baseline = JSON.parse(await readFile("release-baseline.json", "utf8"));
  const candidate = projectOwnedCandidates.find(
    ({ name }) => name === "editor.asm",
  );
  if (candidate === undefined) throw new Error("missing Edit ATOM target");

  const artifacts = await assembleProjectOwnedAtomArtifacts({
    outputDirectory: "src",
    temporaryDirectory,
    candidate,
    base: 0x0100,
    entryAddress: 0x0100,
  });
  const sha256 = createHash("sha256").update(artifacts.bytes).digest("hex");
  if (artifacts.bytes.length !== baseline.bytes || sha256 !== baseline.sha256) {
    throw new Error(
      `EDIT.COM differs from release baseline: ${artifacts.bytes.length} bytes, ${sha256}`,
    );
  }
  const manifest = {
    format: "edit-build-manifest-v1",
    artifact: "EDIT.COM",
    version: baseline.version,
    bytes: artifacts.bytes.length,
    sha256,
    assembler: {
      name: "atom-z80",
      revision: "802b5c2d320bec777f427755ff2d7338e3b80a05",
    },
    loadAddress: 0x0100,
    entryAddress: 0x0100,
    contract: "docs/specification.md",
  };

  await mkdir("dist", { recursive: true });
  await Promise.all([
    writeFile("dist/EDIT.COM", artifacts.bytes),
    writeFile(
      "dist/EDIT.d8.json",
      `${JSON.stringify(artifacts.debugMap, undefined, 2)}\n`,
    ),
    writeFile("dist/manifest.json", `${JSON.stringify(manifest, undefined, 2)}\n`),
  ]);
  console.log(`Built EDIT.COM: ${manifest.bytes} bytes, sha256 ${sha256}`);
} finally {
  await rm(temporaryDirectory, { recursive: true, force: true });
}
