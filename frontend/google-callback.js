// Completes Google sign-in on your callback page (GOOGLE_REDIRECT_URI, for example
// https://your-app.example.com/auth/google/callback).
//
// Reads code and state from the URL and the nonce from this tab's sessionStorage, then sends all three
// to Xano, which verifies the state before exchanging the code. Run completeGoogleSignIn() once when
// the callback page loads.
//
// The callback page must be served from the same origin (scheme + host + port) as the page that called
// startGoogleSignIn(), or sessionStorage will be empty. Add <meta name="referrer" content="no-referrer">
// to the callback page so the code is not leaked in Referer headers.

// Replace with your Xano API base URL and the canonical of the google-oauth API group.
const OAUTH_API_BASE = "https://YOUR_XANO_INSTANCE/api:YOUR_GOOGLE_OAUTH_GROUP";
const NONCE_KEY = "oauth_nonce_google";

export async function completeGoogleSignIn() {
  const params = new URLSearchParams(window.location.search);
  const code = params.get("code");
  const state = params.get("state");
  const providerError = params.get("error");
  const nonce = sessionStorage.getItem(NONCE_KEY);

  // Single use: clear the nonce before anything else, whatever the outcome.
  sessionStorage.removeItem(NONCE_KEY);
  // Remove code and state from the address bar and browser history.
  window.history.replaceState(null, "", window.location.pathname);

  if (providerError) {
    throw new Error("Google sign-in was cancelled or denied.");
  }
  if (!code || !state) {
    throw new Error("Invalid sign-in response. Please try again.");
  }
  if (!nonce) {
    // Expired tab, cleared storage, a different tab or origin, or a link someone sent you.
    // Do not call Xano: without this browser's nonce the callback cannot be verified.
    throw new Error("Sign-in expired. Please try again.");
  }

  const response = await fetch(`${OAUTH_API_BASE}/oauth/google/continue`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ code, state, nonce }),
  });
  if (!response.ok) {
    throw new Error("Sign-in could not be verified. Please try again.");
  }

  // Whatever your continue endpoint returns once you implement its application-authentication block
  // (for example your own session token). Store it the way your app stores sessions.
  return response.json();
}
