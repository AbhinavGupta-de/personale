export interface PendingBrowserEvent {
  id?: number;
  domain: string;
  title: string;
  url: string;
  timestamp: string;
  browser: string;
  synced: number; // 0 = unsynced, 1 = synced (IDB keys must be numbers, not booleans)
}

export interface ExtensionSettings {
  serverURL: string;
  enabled: boolean;
  excludedDomains: string[];
}

export const DEFAULT_SETTINGS: ExtensionSettings = {
  serverURL: "http://localhost:8696",
  enabled: true,
  excludedDomains: [
    // Banking
    "chase.com", "bankofamerica.com", "wellsfargo.com", "citi.com",
    "capitalone.com", "usbank.com", "schwab.com", "fidelity.com",
    // Healthcare
    "mychart.com", "patient.com",
    // Sensitive
    "1password.com", "bitwarden.com", "lastpass.com",
  ],
};

export const DEFAULT_EXCLUDED_PATTERNS = DEFAULT_SETTINGS.excludedDomains;
