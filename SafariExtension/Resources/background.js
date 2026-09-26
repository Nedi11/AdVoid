const api = globalThis.browser ?? globalThis.chrome;
const APP_ID = "com.roxuh.advoid";

// Blocking only runs with a subscription. Content scripts read `active` from storage;
// the network rules are switched here.
const sync = async (reply) => {
  if (typeof reply?.active !== "boolean") return;
  await api.storage.local.set({ active: reply.active });
  await api.declarativeNetRequest.updateEnabledRulesets(
    reply.active ? { enableRulesetIds: ["ads"] } : { disableRulesetIds: ["ads"] },
  );
};

// Forwards counts from content scripts to the native handler, which stores them for the app.
api.runtime.onMessage.addListener((message) => {
  if (message?.type !== "counts") return;
  api.runtime.sendNativeMessage(APP_ID, { counts: message.counts }).then(sync).catch(() => {});
});

// Lets the app know the extension is switched on, and learns whether to block.
api.runtime.sendNativeMessage(APP_ID, { hello: true }).then(sync).catch(() => {});
