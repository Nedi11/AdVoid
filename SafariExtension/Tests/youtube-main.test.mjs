// Run: node SafariExtension/Tests/youtube-main.test.mjs
import { readFileSync } from "node:fs";
import vm from "node:vm";
import assert from "node:assert/strict";

const source = readFileSync(new URL("../Resources/youtube-main.js", import.meta.url), "utf8");
const messages = [];
class FakeResponse { constructor(body) { this.body = body; } json() { return Promise.resolve(JSON.parse(this.body)); } }
const context = {
  JSON: { parse: JSON.parse, stringify: JSON.stringify },
  Response: FakeResponse,
  document: { documentElement: { dataset: {} } },
  location: { origin: "https://m.youtube.com" },
  postMessage: (data) => messages.push(data),
};
context.window = context;
vm.createContext(context);
vm.runInContext(source, context);
vm.runInContext(source, context); // second injection is a no-op

const player = { videoDetails: { videoId: "x" }, streamingData: {}, adPlacements: [1], playerAds: [2], adSlots: [3] };

// 1. Inline initial response
vm.runInContext(`var ytInitialPlayerResponse = ${JSON.stringify(player)};`, context);
const initial = vm.runInContext("ytInitialPlayerResponse", context);
assert.deepEqual(Object.keys(initial).sort(), ["streamingData", "videoDetails"]);

// 2. JSON.parse of a wrapper with playerResponse
const wrapped = context.JSON.parse(JSON.stringify([{ playerResponse: player }, { other: 1 }]));
assert.equal(wrapped[0].playerResponse.adPlacements, undefined);
assert.equal(wrapped[0].playerResponse.videoDetails.videoId, "x");

// 3. fetch Response.json
const fetched = await new FakeResponse(JSON.stringify(player)).json();
assert.equal(fetched.playerAds, undefined);
assert.equal(fetched.adSlots, undefined);

// 4. Ad-free data is untouched and not reported
const before = messages.length;
assert.deepEqual(context.JSON.parse('{"a":1,"b":[1,2]}'), { a: 1, b: [1, 2] });
assert.equal(context.JSON.parse("5"), 5);
assert.equal(context.JSON.parse("null"), null);
assert.equal(messages.length, before);

assert.equal(messages.length, 3);
assert.ok(messages.every((m) => m.advoid === "youtubeAdsStripped"));
console.log("youtube-main.js: all checks passed");
