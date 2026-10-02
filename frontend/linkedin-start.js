// Starts LinkedIn sign-in.
//
// Generates a 256-bit nonce, keeps it in this tab's sessionStorage, sends it to Xano over HTTPS in a
// POST body, and navigates this same tab to the LinkedIn URL Xano returns. The nonce never appears in
// any URL. Call startLinkedInSignIn() from your "Sign in with LinkedIn" button.

// Replace with your Xano API base URL and the canonical of the linkedin-oauth API group.
const OAUTH_API_BASE = "https://YOUR_XANO_INSTANCE/api:YOUR_LINKEDIN_OAUTH_GROUP";

// Separate key per provider, so two sign-ins started in different tabs cannot overwrite each other.
const NONCE_KEY = "oauth_nonce_linkedin";

function generateNonce() {
  const bytes = new Uint8Array(32); // 256 bits
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join(""); // 64 lowercase hex chars
}

export async function startLinkedInSignIn() {
  const nonce = generateNonce();
  sessionStorage.setItem(NONCE_KEY, nonce);

  let authUrl;
  try {
    const response = await fetch(`${OAUTH_API_BASE}/oauth/linkedin/init`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ nonce }),
    });
    if (!response.ok) throw new Error(`init failed: ${response.status}`);
    ({ authUrl } = await response.json());
  } catch (error) {
    sessionStorage.removeItem(NONCE_KEY);
    throw new Error("Could not start LinkedIn sign-in. Please try again.");
  }

  // Only ever navigate to LinkedIn's authorization endpoint.
  if (typeof authUrl !== "string" || !authUrl.startsWith("https://www.linkedin.com/oauth/")) {
    sessionStorage.removeItem(NONCE_KEY);
    throw new Error("Could not start LinkedIn sign-in. Please try again.");
  }

  // Same tab: sessionStorage is per tab, so the callback must load in this tab.
  window.location.assign(authUrl);
}
