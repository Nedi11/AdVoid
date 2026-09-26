// Blocklist parsing and hashing. Must stay byte-for-byte compatible with the
// app's Shared/BlocklistParser.swift and Shared/DomainMatcher.swift, which read
// what this produces. lists/vectors.json is checked by both test suites.

const HOSTS_IGNORED = new Set([
  "localhost", "localhost.localdomain", "local", "broadcasthost",
  "ip6-localhost", "ip6-loopback", "ip6-localnet", "ip6-mcastprefix",
  "ip6-allnodes", "ip6-allrouters", "ip6-allhosts", "0.0.0.0",
]);

const WHITESPACE = /^[ \t]+|[ \t]+$/g;

export function normalize(domain) {
  let d = domain.replace(WHITESPACE, "").toLowerCase();
  while (d.endsWith(".")) d = d.slice(0, -1);
  return d;
}

function isIPAddress(s) {
  if (s.includes(":")) return true;
  const parts = s.split(".");
  return parts.length === 4 && parts.every((p) => /^\+?\d+$/.test(p) && Number(p) <= 255);
}

/** The normalized domain if it looks like a real hostname, otherwise null. */
export function validated(candidate) {
  const d = normalize(candidate);
  if (d.length > 253 || !d.includes(".") || d.startsWith(".") || d.includes("..")) return null;
  if (!/^[a-z0-9._-]+$/.test(d) || isIPAddress(d)) return null;
  return d;
}

export function domainsInLine(rawLine) {
  let line = rawLine;
  const hash = line.indexOf("#");
  if (hash >= 0) line = line.slice(0, hash);
  line = line.replace(WHITESPACE, "");
  if (!line || line.startsWith("!") || line.startsWith("@@") || line.startsWith("[")) return [];

  if (line.startsWith("||")) {
    let rule = line.slice(2);
    const dollar = rule.indexOf("$");
    if (dollar >= 0) {
      if (rule.slice(dollar + 1) !== "important") return [];
      rule = rule.slice(0, dollar);
    }
    if (!rule.endsWith("^")) return [];
    const d = validated(rule.slice(0, -1));
    return d ? [d] : [];
  }

  const fields = line.split(/[ \t]+/).filter(Boolean);
  if (fields.length === 0) return [];

  if (fields.length > 1 && isIPAddress(fields[0])) {
    return fields.slice(1).flatMap((field) => {
      const name = field.toLowerCase();
      if (HOSTS_IGNORED.has(name)) return [];
      const d = validated(name);
      return d ? [d] : [];
    });
  }

  if (fields.length !== 1) return [];
  let domain = fields[0];
  if (domain.startsWith("*.")) domain = domain.slice(2);
  const d = validated(domain);
  return d ? [d] : [];
}

export function parseList(text) {
  return text.split(/\r\n|\r|\n/).flatMap(domainsInLine);
}

const FNV_OFFSET = 0xcbf29ce484222325n;
const FNV_PRIME = 0x100000001b3n;
const MASK = 0xffffffffffffffffn;
const encoder = new TextEncoder();

/** 64-bit FNV-1a over the UTF-8 bytes of the normalized domain. */
export function hashDomain(domain) {
  let h = FNV_OFFSET;
  for (const byte of encoder.encode(normalize(domain))) {
    h ^= BigInt(byte);
    h = (h * FNV_PRIME) & MASK;
  }
  return h;
}

/** Sorted, de-duplicated little-endian UInt64s: the format DomainMatcher memory-maps. */
export function compile(domains) {
  const unique = [...new Set(domains.map(hashDomain))].sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  const buffer = Buffer.alloc(unique.length * 8);
  unique.forEach((h, i) => buffer.writeBigUInt64LE(h, i * 8));
  return { buffer, count: unique.length };
}

/** True if the domain or any parent domain is in the hash set, like DomainMatcher.matches. */
export function matches(hashSet, domain) {
  const labels = normalize(domain).split(".");
  for (let i = 0; i < labels.length; i++) {
    if (hashSet.has(hashDomain(labels.slice(i).join(".")))) return true;
  }
  return false;
}
