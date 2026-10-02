// Starts Google sign-in.
//
// Generates a 256-bit nonce, keeps it in this tab's sessionStorage, sends it to Xano over HTTPS in a
// POST body, and navigates this same tab to the Google URL Xano returns. The nonce never appears in
// any URL. Call startGoogleSignIn() from your "Sign in with Google" button.

// Replace with your Xano API base URL and the canonical of the google-oauth API group.
const OAUTH_API_BASE = "https://YOUR_XANO_INSTANCE/api:YOUR_GOOGLE_OAUTH_GROUP";

// Separate key per provider, so two sign-ins started in different tabs cannot overwrite each other.
const NONCE_KEY = "oauth_nonce_google";

function generateNonce() {
  const bytes = new Uint8Array(32); // 256 bits
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join(""); // 64 lowercase hex chars
}

export async function startGoogleSignIn() {
  const nonce = generateNonce();
  sessionStorage.setItem(NONCE_KEY, nonce);

  let authUrl;
  try {
    const response = await fetch(`${OAUTH_API_BASE}/oauth/google/init`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ nonce }),
    });
    if (!response.ok) throw new Error(`init failed: ${response.status}`);
    ({ authUrl } = await response.json());
  } catch (error) {
    sessionStorage.removeItem(NONCE_KEY);
    throw new Error("Could not start Google sign-in. Please try again.");
  }

  // Only ever navigate to Google's authorization endpoint.
  if (typeof authUrl !== "string" || !authUrl.startsWith("https://accounts.google.com/")) {
    sessionStorage.removeItem(NONCE_KEY);
    throw new Error("Could not start Google sign-in. Please try again.");
  }

  // Same tab: sessionStorage is per tab, so the callback must load in this tab.
  window.location.assign(authUrl);
}
