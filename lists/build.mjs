#!/usr/bin/env node
// Downloads the upstream blocklists, checks them, compiles them into the app's
// hash format and writes a catalog describing them.
//
//   node lists/build.mjs --out dist [--previous previous-catalog.json]
//
// Output (upload the contents of --out to the bucket root):
//   v1/catalog.json            what the app reads first
//   v1/lists/<id>-<hash>.bin   compiled lists, content-addressed so they cache forever
//   keep.txt                   every list file the new catalog references
//
// A list that fails to download, shrinks suspiciously or blocks a protected
// domain keeps its previous version instead of taking the whole build down.

import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { compile, hashDomain, matches, parseList } from "./lib.mjs";

const BASE_URL = "https://lists.roxuh.com";
const MIN_DOMAINS = 1000;
const MAX_SHRINK = 0.5;

const { values: args } = parseArgs({
  options: {
    out: { type: "string", default: "dist" },
    previous: { type: "string" },
    sources: { type: "string", default: new URL("./sources.json", import.meta.url).pathname },
  },
});

const config = JSON.parse(readFileSync(args.sources, "utf8"));
const previous = loadPrevious(args.previous);
const listsDir = join(args.out, "v1", "lists");
mkdirSync(listsDir, { recursive: true });

const entries = [];
const problems = [];

for (const source of config.lists) {
  const prior = previous.get(source.id);
  try {
    const entry = await buildList(source, prior);
    entries.push(entry);
    console.log(`✓ ${source.id}: ${entry.domainCount.toLocaleString()} domains`);
  } catch (error) {
    problems.push(`${source.id}: ${error.message}`);
    if (prior) {
      entries.push({ ...prior, ...describe(source) });
      console.warn(`✗ ${source.id}: ${error.message} (keeping ${prior.updatedAt})`);
    } else {
      console.warn(`✗ ${source.id}: ${error.message} (no previous version, left out)`);
    }
  }
}

if (entries.length === 0) {
  console.error("No lists could be built.");
  process.exit(1);
}

const catalog = {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  publisher: config.publisher,
  notice: config.notice,
  lists: entries,
};

writeFileSync(join(args.out, "v1", "catalog.json"), `${JSON.stringify(catalog, null, 2)}\n`);
writeFileSync(join(args.out, "keep.txt"), `${entries.map((e) => e.file.split("/").pop()).join("\n")}\n`);

if (problems.length) {
  console.warn(`\n${problems.length} list(s) kept their previous version:\n  ${problems.join("\n  ")}`);
}

async function buildList(source, prior) {
  const text = await download(source.url);
  const domains = parseList(text);
  const { buffer, count } = compile(domains);

  if (count < MIN_DOMAINS) throw new Error(`only ${count} domains`);
  if (prior && count < prior.domainCount * MAX_SHRINK) {
    throw new Error(`shrank from ${prior.domainCount} to ${count} domains`);
  }
  const hashes = new Set(domains.map(hashDomain));
  const blockedProtected = config.protectedDomains.filter((d) => matches(hashes, d));
  if (blockedProtected.length) throw new Error(`blocks protected domains: ${blockedProtected.join(", ")}`);

  const sha256 = createHash("sha256").update(buffer).digest("hex");
  const fileName = `${source.id}-${sha256.slice(0, 16)}.bin`;
  writeFileSync(join(listsDir, fileName), buffer);

  const unchanged = prior?.sha256 === sha256;
  return {
    ...describe(source),
    file: `${BASE_URL}/v1/lists/${fileName}`,
    sha256,
    bytes: buffer.length,
    domainCount: count,
    updatedAt: unchanged ? prior.updatedAt : new Date().toISOString(),
  };
}

function describe(source) {
  return {
    id: source.id,
    name: source.name,
    description: source.description,
    enabledByDefault: source.enabledByDefault,
    source: { url: source.url, author: source.author, homepage: source.homepage },
    license: source.license,
  };
}

async function download(url) {
  let lastError;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(60_000) });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return await response.text();
    } catch (error) {
      lastError = error;
      await new Promise((resolve) => setTimeout(resolve, attempt * 2000));
    }
  }
  throw new Error(`download failed: ${lastError.message}`);
}

function loadPrevious(path) {
  if (!path) return new Map();
  try {
    const catalog = JSON.parse(readFileSync(path, "utf8"));
    return new Map(catalog.lists.map((entry) => [entry.id, entry]));
  } catch {
    return new Map();
  }
}
