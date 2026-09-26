// Hides sponsored posts in the instagram.com feed.
(() => {
  const api = globalThis.browser ?? globalThis.chrome;
  const LABEL = /^(Sponsored|Gesponsert|Sponsorisé|Sponsorizzato|Patrocinado|Publicidad|Gesponsord|Sponsrad|Sponsoreret|Sponset|Sponsoroitu|Sponsorowane|Реклама|Sponzorováno|Sponsorlu|Χορηγούμενη|広告|광고|赞助内容|贊助)$/;

  const checked = new WeakSet();
  let hidden = 0;

  const isSponsored = (post) => {
    for (const el of post.querySelectorAll("span, a, div")) {
      if (el.childElementCount === 0 && LABEL.test(el.textContent.trim())) return true;
    }
    return false;
  };

  const scan = () => {
    for (const post of document.querySelectorAll("article")) {
      if (checked.has(post)) continue;
      if (isSponsored(post)) {
        checked.add(post);
        post.style.setProperty("display", "none", "important");
        hidden += 1;
      } else if (post.querySelector("img, video")) {
        // Only mark as checked once the post has loaded; the label renders with it.
        checked.add(post);
      }
    }
  };

  let queued = false;
  new MutationObserver(() => {
    if (queued) return;
    queued = true;
    setTimeout(() => { queued = false; scan(); }, 300);
  }).observe(document.documentElement, { childList: true, subtree: true });
  scan();

  setInterval(() => {
    if (!hidden) return;
    api.runtime.sendMessage({ type: "counts", counts: { instagramSponsoredHidden: hidden } }).catch(() => {});
    hidden = 0;
  }, 5000);
})();
