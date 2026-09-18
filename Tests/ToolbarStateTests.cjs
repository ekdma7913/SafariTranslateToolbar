const { test } = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");
const { runInNewContext } = require("node:vm");
const source = readFileSync(join(__dirname,
    "../SafariTranslateToolbar/SafariTranslateToolbar Extension/Resources/background.js"), "utf8");
const flush = () => new Promise(setImmediate);

function harness({ response = { ok: true }, colorFails = false } = {}) {
    const event = () => ({ listeners: [], addListener(fn) { this.listeners.push(fn); },
        fire(...args) { return Promise.all(this.listeners.map(fn => fn(...args))); } });
    const calls = [], sent = [], ports = [], timers = new Set();
    const action = { onClicked: event() };
    for (const method of ["setIcon", "setBadgeBackgroundColor", "setBadgeText", "setTitle"]) {
        action[method] = async details => {
            if (colorFails && method === "setBadgeBackgroundColor") throw Error("unsupported");
            calls.push({ method, ...details });
        };
    }
    const browser = {
        action, i18n: { getMessage: () => "" },
        runtime: {
            onStartup: event(), onInstalled: event(),
            connectNative() {
                const port = { onMessage: event(), onDisconnect: event(),
                    disconnect() { this.onDisconnect.fire(); } };
                ports.push(port); return port;
            },
            async sendNativeMessage(app, payload) { sent.push({ app, ...payload }); return response; },
        },
        tabs: { onUpdated: event(), onActivated: event(), onRemoved: event(),
            query: async () => [{ id: 1 }, { id: 2 }] },
        windows: { onFocusChanged: event() },
    };
    let sequence = 0;
    runInNewContext(source, { browser, crypto: { randomUUID: () => `request-${++sequence}` },
        setTimeout(fn) { timers.add(fn); return fn; }, clearTimeout(fn) { timers.delete(fn); } });
    return {
        browser, sent, ports, timers, calls,
        async click(tabId = 1) { await action.onClicked.fire({ id: tabId, windowId: 10 }); await flush(); },
        async reply(state, requestID = sent.at(-1).requestID) {
            await ports.at(-1).onMessage.fire({ userInfo: { state, requestID } }); await flush();
        },
        badge(tabId = 1) { return calls.filter(c => c.method === "setBadgeText" && c.tabId === tabId).at(-1)?.text; },
    };
}

test("acknowledgment does not light badge; confirmed translation then original toggles it", async () => {
    const h = harness(); await h.click();
    assert.equal(h.badge(), "…");
    await h.reply("translated"); assert.equal(h.badge(), "ON");
    assert.ok(h.calls.some(c => c.path === "images/toolbar-icon-on.svg"));
    await h.click(); await h.reply("original"); assert.equal(h.badge(), "");
    assert.equal(h.timers.size, 0);
});
test("rapid repeated clicks dispatch one native command", async () => {
    const h = harness(); await h.click(); await h.click(); assert.equal(h.sent.length, 1);
});
test("unrelated replies and invalid states cannot change the badge", async () => {
    const h = harness(); await h.click(); await h.reply("translated", "other");
    await h.reply("anything"); assert.equal(h.badge(), "…");
});
test("navigation clears the badge and discards a late native reply", async () => {
    const h = harness(); await h.click(); const requestID = h.sent[0].requestID;
    await h.browser.tabs.onUpdated.fire(1, { status: "loading" }); await h.reply("translated", requestID);
    assert.equal(h.badge(), "");
});
test("tab and window switches discard a pending result", async () => {
    for (const kind of ["tab", "window"]) {
        const h = harness(); await h.click();
        if (kind === "tab") await h.browser.tabs.onActivated.fire({ tabId: 2, windowId: 10 });
        else await h.browser.windows.onFocusChanged.fire(11);
        await h.reply("translated"); assert.equal(h.badge(), "?"); assert.notEqual(h.badge(2), "ON");
    }
});
test("native rejection, unknown result and timeout never claim success", async () => {
    const rejected = harness({ response: { ok: false } }); await rejected.click();
    assert.equal(rejected.badge(), "?");
    const h = harness(); await h.click(); await h.reply("unknown"); assert.equal(h.badge(), "?");
    await h.click(); for (const timer of [...h.timers]) timer(); await flush(); assert.equal(h.badge(), "?");
});
test("disconnected native port clears pending state", async () => {
    const h = harness(); await h.click(); await h.ports[0].onDisconnect.fire(); await flush();
    assert.equal(h.badge(), "?"); await h.click(); assert.equal(h.sent.length, 2);
});
test("badge text still works without Safari badge color support", async () => {
    const h = harness({ colorFails: true }); await h.click(); await h.reply("translated");
    assert.equal(h.badge(), "ON");
});
test("tab metadata is not read or sent to the companion", async () => {
    const h = harness(); const tab = { id: 1, windowId: 10 };
    for (const key of ["url", "title", "favIconUrl"]) {
        Object.defineProperty(tab, key, { get() { throw Error("private tab metadata accessed"); } });
    }
    await h.browser.action.onClicked.fire(tab);
    assert.deepEqual(Object.keys(h.sent[0]).sort(), ["app", "command", "requestID"]);
});
test("closing a tab and browser startup do not retain a stale ON badge", async () => {
    const h = harness(); await h.browser.runtime.onStartup.fire(); await flush(); assert.equal(h.badge(), "");
    await h.click(); await h.browser.tabs.onRemoved.fire(1); await h.reply("translated");
    assert.notEqual(h.badge(), "ON");
});
test("background wake-up does not clear browser-managed per-tab state", async () => {
    const h = harness(); await flush(); assert.equal(h.calls.length, 0);
    await h.browser.runtime.onInstalled.fire(); await flush(); assert.equal(h.badge(), "");
});
