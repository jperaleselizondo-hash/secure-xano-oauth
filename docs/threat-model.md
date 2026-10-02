# Threat model

## Assets

- The victim's session in **their own** application account.
- Data the victim enters while signed in.
- Provider client secrets and `OAUTH_STATE_SECRET`.

## Primary threat: login CSRF (session swapping)

**Attacker goal:** get the victim's browser signed in to an account the attacker controls, so that the
victim's later actions and data land in the attacker's account.

**Naive flow weakness:** `continue` accepts any valid authorization code. The attacker obtains a code for
their own provider identity and delivers `callback?code=…` to the victim.

**Mitigation:** every callback must present a state signed by the server *and* the nonce whose hash is
bound into that state. The nonce exists only in the starting tab's `sessionStorage`.

| Attacker attempt | Why it fails |
|---|---|
| Send the victim a callback link with the attacker's code and state | The victim's tab has no matching nonce (or none at all), so `sha256(nonce) ≠ bh` → 403, or the page stops before calling Xano |
| Send a link with only a code, no state | `state` is required, so the request is refused before the exchange |
| Forge or edit a state (for example, put in the hash of a nonce the attacker chose) | The HMAC fails without `OAUTH_STATE_SECRET` |
| Reuse a Google state on the LinkedIn callback | The `p` claim does not match the provider → 403 |
| Use an old state | `exp` has passed → 403 |
| Write a nonce into the victim's `sessionStorage` | Not possible from another origin |
| Put the nonce on the URL to make the victim send it | The frontend never reads the nonce from the URL |
| Call `continue` directly with their own state and nonce | Signs in only the attacker, in the attacker's own browser, which is not an attack |

## Secondary properties

- **Code is not consumed by unverified requests:** verification runs before the token exchange.
- **No secrets in URLs:** the code exchange sends credentials in a POST form body; the nonce and code
  reach Xano in POST bodies; the userinfo call uses an `Authorization` header.
- **No client-chosen redirect URI:** redirect URIs come from server environment variables.
- **No information leaks through errors:** every verification failure gets one generic message, and
  provider errors are replaced with generic text.
- **Partial setups fail closed:** the `continue` endpoints refuse to complete until the application
  authentication logic is implemented.

## Out of scope / residual risks

| Risk | Notes |
|---|---|
| XSS on the frontend origin | Script on your origin can read `sessionStorage` and act as the user. Mitigate with CSP and minimal third-party scripts. |
| Account takeover through email-based linking | Belongs to your integration logic. Link by `(provider, sub)`, and link by email only when it is verified on both sides. |
| Pre-account-takeover via unverified sign-up | Belongs to your sign-up and email verification logic. |
| State replay within 10 minutes | A state is not marked as used on the server. Replay requires the victim's nonce (unobtainable) and a fresh provider code bound to the same state. Add a used-state record if you need strict single use. |
| Timing side channel on HMAC comparison | Xano offers no constant-time compare. Not considered practical over the network for a 256-bit HMAC. |
| Brute force or abuse of public endpoints | Add rate limiting or bot protection. |
| Leaked `OAUTH_STATE_SECRET` | An attacker could mint states, but would still need the victim's nonce for a cross-browser attack. Rotate the secret immediately. |
| Leaked provider client secret | Rotate it in the provider console and in Xano. |
| Open redirects after sign-in | Belongs to your frontend. Allowlist post-login destinations. |
| Compromised provider account | Out of scope. |

## Alternatives considered

| Alternative | Why not used |
|---|---|
| Random `state` stored only in the browser and compared on the callback page | Depends entirely on frontend correctness; no server-side integrity, provider binding or expiry. |
| Server-side state table or cache | Adds a table, a cleanup job and schema changes; still needs a browser-held secret to bind the callback to the browser. |
| PKCE only | PKCE support differs by provider and app type, so it cannot be relied on to protect every provider the same way. Signed state works for any provider that returns `state`. PKCE can be added on top where available. |
| Cookie set by Xano | From the frontend's point of view this is a third-party cookie on the Xano domain, which browsers may block. |
| Nonce in `localStorage` | Shared across tabs and persists after the tab closes; `sessionStorage` is narrower. |
