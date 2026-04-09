const defaults = {
  serverURL: "http://localhost:8696",
  enabled: true,
  excludedDomains: ["chase.com","bankofamerica.com","wellsfargo.com","citi.com","capitalone.com","usbank.com","schwab.com","fidelity.com","mychart.com","patient.com","1password.com","bitwarden.com","lastpass.com"],
};

chrome.storage.sync.get(["serverURL", "enabled", "excludedDomains"], (data) => {
  document.getElementById("serverURL").value = data.serverURL ?? defaults.serverURL;
  document.getElementById("enabled").checked = data.enabled ?? defaults.enabled;
  document.getElementById("excludedDomains").value = (data.excludedDomains ?? defaults.excludedDomains).join("\n");
});

document.getElementById("save").addEventListener("click", () => {
  const serverURL = document.getElementById("serverURL").value.trim();
  const enabled = document.getElementById("enabled").checked;
  const excludedDomains = document.getElementById("excludedDomains").value
    .split("\n").map(s => s.trim()).filter(Boolean);

  chrome.storage.sync.set({ serverURL, enabled, excludedDomains }, () => {
    document.getElementById("status").textContent = "Saved!";
    setTimeout(() => document.getElementById("status").textContent = "", 2000);
  });
});
