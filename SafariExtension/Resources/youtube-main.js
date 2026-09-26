// Runs in the page's own JavaScript world, before YouTube's scripts.
// Removes ad schedules from player data so the player never learns there are ads.
(() => {
  if (document.documentElement.dataset.advoidMain) return;
  document.documentElement.dataset.advoidMain = "1";

  const AD_KEYS = ["adPlacements", "adSlots", "playerAds", "adBreakHeartbeatParams"];

  const report = () => window.postMessage({ advoid: "youtubeAdsStripped" }, window.location.origin);

  // Strips ad keys from a player response, or from a wrapper holding one.
  // Returns true if anything was removed.
  const prune = (data) => {
    // Set by youtube.js when there's no subscription.
    if (document.documentElement.dataset.advoidOff) return false;
    if (!data || typeof data !== "object") return false;
    let removed = false;
    const targets = Array.isArray(data) ? data : [data];
    for (const item of targets) {
      if (!item || typeof item !== "object") continue;
      for (const candidate of [item, item.playerResponse]) {
        if (!candidate || typeof candidate !== "object") continue;
        for (const key of AD_KEYS) {
          if (key in candidate) {
            delete candidate[key];
            removed = true;
          }
        }
      }
    }
    if (removed) report();
    return removed;
  };

  // Responses loaded later (next video, autoplay) come through JSON.parse or Response.json.
  const originalParse = JSON.parse;
  JSON.parse = function (...args) {
    const result = originalParse.apply(this, args);
    try { prune(result); } catch {}
    return result;
  };

  const originalJson = Response.prototype.json;
  Response.prototype.json = function (...args) {
    return originalJson.apply(this, args).then((result) => {
      try { prune(result); } catch {}
      return result;
    });
  };

  // The first video's data is assigned inline in the HTML.
  for (const name of ["ytInitialPlayerResponse"]) {
    let value;
    try {
      Object.defineProperty(window, name, {
        configurable: true,
        get: () => value,
        set: (next) => {
          try { prune(next); } catch {}
          value = next;
        },
      });
    } catch {}
  }
})();
