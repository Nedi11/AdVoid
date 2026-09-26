// Runs in the extension's isolated world on YouTube.
// Backstop for anything the data pruning misses: skips ads that still play,
// counts hidden ad slots, and reports totals to the app.
(() => {
  const api = globalThis.browser ?? globalThis.chrome;

  // Safari versions without main-world content scripts: inject it as a page script instead.
  if (!document.documentElement.dataset.advoidMain) {
    const script = document.createElement("script");
    script.src = api.runtime.getURL("youtube-main.js");
    (document.head || document.documentElement).appendChild(script);
    script.remove();
  }

  const counts = {};
  const bump = (key, n = 1) => { counts[key] = (counts[key] || 0) + n; };

  window.addEventListener("message", (event) => {
    if (event.source === window && event.data?.advoid === "youtubeAdsStripped") bump("youtubeAdsStripped");
  });

  const SKIP_BUTTONS = [
    ".ytp-skip-ad-button",
    ".ytp-ad-skip-button",
    ".ytp-ad-skip-button-modern",
    ".ytp-ad-skip-button-slot button",
    ".ytm-skip-ad-button",
  ].join(",");

  const AD_SLOTS = [
    "ad-slot-renderer",
    "ytm-promoted-sparkles-web-renderer",
    "ytm-promoted-video-renderer",
    "ytm-companion-ad-renderer",
    "ytd-ad-slot-renderer",
    "ytd-in-feed-ad-layout-renderer",
    "ytd-promoted-sparkles-web-renderer",
    "ytd-banner-promo-renderer",
    "#masthead-ad",
    "#player-ads",
  ].join(",");

  let inAd = false;
  const seenSlots = new WeakSet();

  const tick = () => {
    const player = document.querySelector(".ad-showing");
    if (player) {
      const video = player.querySelector("video");
      if (video) {
        video.muted = true;
        if (Number.isFinite(video.duration) && video.duration > 0) video.currentTime = video.duration;
      }
      document.querySelectorAll(SKIP_BUTTONS).forEach((button) => button.click());
      if (!inAd) bump("youtubeAdsSkipped");
      inAd = true;
    } else if (inAd) {
      inAd = false;
      const video = document.querySelector("#movie_player video, .html5-video-player video");
      if (video) video.muted = false;
    }

    document.querySelectorAll(AD_SLOTS).forEach((slot) => {
      if (seenSlots.has(slot)) return;
      seenSlots.add(slot);
      bump("youtubeSlotsHidden");
    });
  };

  setInterval(tick, 250);

  setInterval(() => {
    if (!Object.keys(counts).length) return;
    api.runtime.sendMessage({ type: "counts", counts: { ...counts } }).catch(() => {});
    for (const key of Object.keys(counts)) delete counts[key];
  }, 5000);
})();
