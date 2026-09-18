// Only opaque tab IDs and per-click tokens live in memory. No tabs permission,
// page inspection, URL/title access, storage, or background polling is needed.
const nativeApp = "com.team95788x96a7.safari-translate-toolbar";
const states = new Map();
const renders = new Map();
let pending = null;
const message = (key, fallback) => browser.i18n.getMessage(key) || fallback;

function render(tabId, state) {
    const revision = {};
    states.set(tabId, revision);
    // Serialize writes so a slow earlier render cannot overwrite a newer state.
    const update = (renders.get(tabId) || Promise.resolve()).then(async () => {
        const translated = state === "translated";
        const text = translated ? "ON" : state === "pending" ? "…" : state === "unknown" ? "?" : "";
        const title = state === "translated"
            ? message("action_original", "Show Original Page")
            : state === "pending" ? message("action_pending", "Changing translation…")
            : state === "unknown" ? message("action_unknown", "State not confirmed — click to toggle translation")
            : message("action_title", "Toggle Apple Translation / Original Page");
        for (const [method, details] of [
            ["setIcon", { path: translated ? "images/toolbar-icon-on.svg" : "images/toolbar-icon.svg" }],
            ["setBadgeBackgroundColor", { color: translated ? "#007AFF" : "#6E6E73" }],
            ["setBadgeText", { text }],
            ["setTitle", { title }],
        ]) {
            if (states.get(tabId) !== revision) return;
            try { await browser.action[method]?.({ tabId, ...details }); }
            catch { /* Safari may not support badge colors; retain text/shape. */ }
        }
    });
    renders.set(tabId, update);
    update.finally(() => {
        if (renders.get(tabId) === update) renders.delete(tabId);
    });
    return update;
}

function finish(request, state) {
    if (pending !== request) return;
    pending = null;
    clearTimeout(request.timer);
    try { request.port?.disconnect(); } catch { /* Already disconnected. */ }
    void render(request.tabId, state);
}

browser.action.onClicked.addListener(async (tab) => {
    // Safari UI automation targets one foreground page; don't queue rapid clicks.
    if (pending || !Number.isInteger(tab?.id)) return;
    const request = { tabId: tab.id, windowId: tab.windowId, requestID: crypto.randomUUID() };
    pending = request;
    void render(tab.id, "pending");
    request.timer = setTimeout(() => finish(request, "unknown"), 12000);
    try {
        const port = browser.runtime.connectNative(nativeApp);
        request.port = port;
        port.onMessage.addListener((envelope) => {
            const payload = envelope?.userInfo ?? envelope;
            if (payload?.requestID !== request.requestID ||
                !["translated", "original", "unknown"].includes(payload?.state)) return;
            finish(request, payload.state);
        });
        port.onDisconnect.addListener(() => finish(request, "unknown"));
        const response = await browser.runtime.sendNativeMessage(nativeApp, {
            command: "translate", requestID: request.requestID,
        });
        // An open-app acknowledgment is not evidence that translation succeeded.
        if (!response?.ok) finish(request, "unknown");
    } catch {
        finish(request, "unknown");
    }
});

browser.tabs.onUpdated.addListener((tabId, changeInfo) => {
    if (changeInfo.status !== "loading") return;
    if (pending?.tabId === tabId) finish(pending, "unknown");
    void render(tabId, "neutral");
});
browser.tabs.onActivated.addListener(({ tabId, windowId }) => {
    if (pending && pending.windowId === windowId && pending.tabId !== tabId) {
        finish(pending, "unknown");
    }
});
browser.windows.onFocusChanged.addListener((windowId) => {
    if (pending && windowId !== pending.windowId) finish(pending, "unknown");
});
browser.tabs.onRemoved.addListener((tabId) => {
    if (pending?.tabId === tabId) finish(pending, "unknown");
    states.delete(tabId);
});

// Safari owns each tab's last confirmed badge across background suspension.
// Reset only on browser startup/update, not every background-script wake-up.
function resetIndicators() {
    return browser.tabs.query({}).then((tabs) => {
        for (const tab of tabs) {
            if (!states.has(tab.id)) void render(tab.id, "neutral");
        }
    }).catch(() => {});
}
browser.runtime.onStartup.addListener(resetIndicators);
browser.runtime.onInstalled.addListener(resetIndicators);
