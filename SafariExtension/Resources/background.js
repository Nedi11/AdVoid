const api = globalThis.browser ?? globalThis.chrome;
const APP_ID = "com.roxuh.shield";

// Forwards counts from content scripts to the native handler, which stores them for the app.
api.runtime.onMessage.addListener((message) => {
  if (message?.type !== "counts") return;
  api.runtime.sendNativeMessage(APP_ID, { counts: message.counts }).catch(() => {});
});

// Lets the app know the extension is switched on.
api.runtime.sendNativeMessage(APP_ID, { hello: true }).catch(() => {});
