// Run: node --test lists/lib.test.mjs
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { compile, domainsInLine, hashDomain, matches } from "./lib.mjs";

const vectors = JSON.parse(readFileSync(new URL("./vectors.json", import.meta.url), "utf8"));

test("parses lines like the app", () => {
  for (const { line, domains } of vectors.parse) assert.deepEqual(domainsInLine(line), domains, line);
});

test("hashes like the app", () => {
  for (const { domain, fnv1a64 } of vectors.hash) {
    assert.equal(hashDomain(domain).toString(16).padStart(16, "0"), fnv1a64, domain);
  }
  // Published FNV-1a 64 test values.
  assert.equal(hashDomain(""), 0xcbf29ce484222325n);
  assert.equal(hashDomain("a"), 0xaf63dc4c8601ec8cn);
});

test("compiles sorted, unique little-endian hashes", () => {
  const { buffer, count } = compile(["b.com", "a.com", "b.com", "B.com."]);
  assert.equal(count, 2);
  assert.equal(buffer.length, 16);
  assert.ok(buffer.readBigUInt64LE(0) < buffer.readBigUInt64LE(8));
});

test("matches subdomains but not parents", () => {
  const set = new Set(["ads.example.com"].map(hashDomain));
  assert.ok(matches(set, "x.ads.example.com"));
  assert.ok(!matches(set, "example.com"));
  assert.ok(!matches(set, "badads.example.com"));
});
