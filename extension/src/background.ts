import { PendingBrowserEvent, ExtensionSettings, DEFAULT_SETTINGS } from "./types.js";

// ── Settings ──

let settings: ExtensionSettings = { ...DEFAULT_SETTINGS };

async function loadSettings(): Promise<void> {
  const stored = await chrome.storage.sync.get(["serverURL", "enabled", "excludedDomains"]);
  settings = {
    serverURL: stored.serverURL ?? DEFAULT_SETTINGS.serverURL,
    enabled: stored.enabled ?? DEFAULT_SETTINGS.enabled,
    excludedDomains: stored.excludedDomains ?? DEFAULT_SETTINGS.excludedDomains,
  };
}

// ── Privacy ──

function extractDomain(url: string): string | null {
  try {
    const u = new URL(url);
    if (u.protocol !== "http:" && u.protocol !== "https:") return null;
    return u.hostname;
  } catch {
    return null;
  }
}

function truncateUrl(url: string): string {
  try {
    const u = new URL(url);
    return u.origin + u.pathname;
  } catch {
    return url;
  }
}

function isExcluded(domain: string): boolean {
  return settings.excludedDomains.some(
    (excluded) => domain === excluded || domain.endsWith("." + excluded)
  );
}

function detectBrowser(): string {
  const ua = navigator.userAgent;
  if (ua.includes("Brave")) return "brave";
  if (ua.includes("Edg/")) return "edge";
  if (ua.includes("Chrome")) return "chrome";
  return "unknown";
}

// ── IndexedDB ──

const DB_NAME = "personale_browser_events";
const DB_VERSION = 1;
const STORE_NAME = "events";

function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        const store = db.createObjectStore(STORE_NAME, { keyPath: "id", autoIncrement: true });
        store.createIndex("synced", "synced", { unique: false });
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function insertEvent(event: Omit<PendingBrowserEvent, "id">): Promise<void> {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readwrite");
    tx.objectStore(STORE_NAME).add(event);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

async function getUnsynced(limit = 50): Promise<PendingBrowserEvent[]> {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readonly");
    const index = tx.objectStore(STORE_NAME).index("synced");
    const req = index.getAll(IDBKeyRange.only(0), limit);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function markSynced(id: number): Promise<void> {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readwrite");
    const store = tx.objectStore(STORE_NAME);
    const req = store.get(id);
    req.onsuccess = () => {
      const record = req.result;
      if (record) {
        record.synced = 1;
        store.put(record);
      }
      tx.oncomplete = () => resolve();
    };
    tx.onerror = () => reject(tx.error);
  });
}

async function cleanupOldSynced(days = 7): Promise<void> {
  const db = await openDB();
  const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readwrite");
    const store = tx.objectStore(STORE_NAME);
    const req = store.openCursor();
    req.onsuccess = () => {
      const cursor = req.result;
      if (cursor) {
        const record = cursor.value as PendingBrowserEvent;
        if (record.synced === 1 && record.timestamp < cutoff) {
          cursor.delete();
        }
        cursor.continue();
      }
    };
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

// ── Single-flight Flush ──

let isFlushing = false;
let retryTimeout: ReturnType<typeof setTimeout> | null = null;

async function triggerFlush(): Promise<void> {
  if (isFlushing) return;
  isFlushing = true;
  try {
    await flushNext();
  } finally {
    isFlushing = false;
  }
}

async function flushNext(): Promise<void> {
  const events = await getUnsynced(1);
  if (events.length === 0) return;

  const event = events[0];
  try {
    const response = await fetch(`${settings.serverURL}/api/events/browser`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        domain: event.domain,
        title: event.title,
        url: event.url,
        browser: event.browser,
        timestamp: event.timestamp,
      }),
    });

    if (response.ok) {
      await markSynced(event.id!);
      await flushNext();
    } else {
      scheduleRetry();
    }
  } catch {
    scheduleRetry();
  }
}

function scheduleRetry(): void {
  if (retryTimeout) clearTimeout(retryTimeout);
  retryTimeout = setTimeout(() => triggerFlush(), 30_000);
}

// ── Tab Tracking ──

let lastDomain: string | null = null;
let lastEventTime = 0;
const DEBOUNCE_MS = 1000;

async function handleTabChange(tab: chrome.tabs.Tab): Promise<void> {
  if (!settings.enabled) return;
  if (!tab.url) return;

  const domain = extractDomain(tab.url);
  if (!domain) return;
  if (isExcluded(domain)) return;

  const now = Date.now();
  if (domain === lastDomain && now - lastEventTime < DEBOUNCE_MS) return;

  lastDomain = domain;
  lastEventTime = now;

  const event: Omit<PendingBrowserEvent, "id"> = {
    domain,
    title: tab.title ?? "",
    url: truncateUrl(tab.url),
    timestamp: new Date().toISOString(),
    browser: detectBrowser(),
    synced: 0,
  };

  await insertEvent(event);
  triggerFlush();
}

// ── Event Listeners ──

chrome.tabs.onActivated.addListener(async (activeInfo) => {
  try {
    const tab = await chrome.tabs.get(activeInfo.tabId);
    handleTabChange(tab);
  } catch {
    // Tab may have been closed before we could query it
  }
});

chrome.tabs.onUpdated.addListener((_tabId, changeInfo, tab) => {
  // Only track if this is the active tab (ignore background tab updates)
  if ((changeInfo.url || changeInfo.title) && tab.active) {
    handleTabChange(tab);
  }
});

// ── Alarms (survives service worker suspension) ──

chrome.alarms.create("personale-flush", { periodInMinutes: 1 });
chrome.alarms.create("personale-cleanup", { periodInMinutes: 60 * 24 });

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "personale-flush") {
    triggerFlush();
  } else if (alarm.name === "personale-cleanup") {
    cleanupOldSynced();
  }
});

// Also flush + capture on service worker startup (fires every time worker wakes)
loadSettings().then(async () => {
  triggerFlush();
  cleanupOldSynced();
  // Capture current tab on wake — catches what happened while worker was suspended
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (tab) handleTabChange(tab);
  } catch { /* no active tab */ }
});

chrome.storage.onChanged.addListener((changes) => {
  if (changes.serverURL) settings.serverURL = changes.serverURL.newValue;
  if (changes.enabled) settings.enabled = changes.enabled.newValue;
  if (changes.excludedDomains) settings.excludedDomains = changes.excludedDomains.newValue;
});
