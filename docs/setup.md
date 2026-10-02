# Setup

## 1. Provider configuration

### Google

Console menus change over time; the names below describe what to create rather than exact click paths.

1. In the Google Cloud console, configure the OAuth consent screen (branding/audience) for your project.
   The scopes used are `openid`, `email` and `profile`.
2. Create an **OAuth client** of type **Web application**.
3. **Authorized redirect URI:** `https://your-app.example.com/auth/google/callback`
4. Copy the client ID and client secret into Xano as `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`.

### LinkedIn

1. In the LinkedIn developer portal, create an app and add the **Sign In with LinkedIn using OpenID
   Connect** product.
2. In the app's auth settings, add the **authorized redirect URL:**
   `https://your-app.example.com/auth/linkedin/callback`
3. Copy the client ID and client secret into Xano as `LINKEDIN_CLIENT_ID` and `LINKEDIN_CLIENT_SECRET`.

Redirect URIs must match **exactly** what you set in `GOOGLE_REDIRECT_URI` / `LINKEDIN_REDIRECT_URI`.

For local testing you can register an extra redirect URI such as
`http://localhost:3000/auth/google/callback`. Remove it when you are done, and remember that
`GOOGLE_REDIRECT_URI` is workspace-wide.

## 2. Xano environment variables

Xano → Settings → Environment Variables:

```
GOOGLE_CLIENT_ID        = GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET    = GOOGLE_CLIENT_SECRET
GOOGLE_REDIRECT_URI     = https://your-app.example.com/auth/google/callback
LINKEDIN_CLIENT_ID      = LINKEDIN_CLIENT_ID
LINKEDIN_CLIENT_SECRET  = LINKEDIN_CLIENT_SECRET
LINKEDIN_REDIRECT_URI   = https://your-app.example.com/auth/linkedin/callback
OAUTH_STATE_SECRET      = <output of: openssl rand -hex 32>
```

Generate `OAUTH_STATE_SECRET` on your own machine and paste it straight into Xano. Don't put it in chat,
tickets, Git or logs.

## 3. Xano code

Create these in your workspace, either by pasting into the XanoScript editor or by pushing with the Xano
CLI:

| File | Type |
|---|---|
| `xano/functions/oauth_state_issue.xs` | Function |
| `xano/functions/oauth_state_verify.xs` | Function |
| `xano/functions/google_oauth_getauthurl.xs` | Function |
| `xano/functions/google_oauth_get_identity.xs` | Function |
| `xano/functions/linkedin_oauth_getauthurl.xs` | Function |
| `xano/functions/linkedin_oauth_get_identity.xs` | Function |
| `xano/api/google/api_group.xs` | API group `google-oauth` |
| `xano/api/google/init_POST.xs`, `continue_POST.xs` | Endpoints |
| `xano/api/linkedin/api_group.xs` | API group `linkedin-oauth` |
| `xano/api/linkedin/init_POST.xs`, `continue_POST.xs` | Endpoints |

- Replace the placeholder API group canonicals (`your-app-google-oauth`, `your-app-linkedin-oauth`)
  with values unique on your Xano instance.
- If your workspace already has functions with these names, rename them consistently, or compare
  before overwriting.
- Implement the **YOUR APPLICATION AUTHENTICATION LOGIC HERE** block in both `continue` endpoints
  (see the README).
- If you use Xano branches, test on a non-live branch first. A non-live code branch may still use your
  live data source.

## 4. Frontend

Set `OAUTH_API_BASE` in the four files in `frontend/`:

```js
const OAUTH_API_BASE = "https://YOUR_XANO_INSTANCE/api:YOUR_GOOGLE_OAUTH_GROUP";
```

Wire the start functions to your buttons and run the callback functions on the callback pages. The
README's [Frontend setup](../README.md#9-frontend-setup) section lists the requirements (same origin,
same tab, no-referrer, run once).

## Testing

The commands below use placeholders. Set:

```sh
API_GOOGLE="https://YOUR_XANO_INSTANCE/api:YOUR_GOOGLE_OAUTH_GROUP"
API_LINKEDIN="https://YOUR_XANO_INSTANCE/api:YOUR_LINKEDIN_OAUTH_GROUP"
```

They use fake codes, so they never sign anyone in and never consume a real code.

### Issue a state

```sh
NONCE=$(openssl rand -hex 32)
curl -s -X POST "$API_GOOGLE/oauth/google/init" \
  -H 'Content-Type: application/json' -d "{\"nonce\":\"$NONCE\"}"
# → {"authUrl":"https://accounts.google.com/o/oauth2/v2/auth?...&state=..."}
```

Check that the URL contains `state` and does **not** contain `$NONCE`. Copy the URL-decoded `state` value
into `STATE`. The part before `~` decodes to `{"p":"google","exp":…,"bh":"<sha256 of NONCE>"}`.

Xano's base64url output may contain `.` as padding, so for a local decode, strip the dots and add `=`
padding back before decoding.

### Matrix

| # | Request | Expected |
|---|---|---|
| 1 | `init` with `{"nonce":"$NONCE"}` | 200 `{authUrl}` with state, no raw nonce |
| 2 | `init` with `{"nonce":"abc"}` or an uppercase hex nonce | 400 "Invalid sign-in request" |
| 3 | `init` with no body | 400 |
| 4 | `continue` with `code=fake`, `state=$STATE`, `nonce=$NONCE` | 403 "Sign-in with Google failed" (verification **passed**; the provider rejected the fake code) |
| 5 | as 4 but with another nonce (`openssl rand -hex 32`) | 403 "Sign-in could not be verified" |
| 6 | as 4 with one character of the signature changed | 403 "Sign-in could not be verified" |
| 7 | as 4 with the payload changed (re-encoded with a different `bh`), signature kept | 403 "Sign-in could not be verified" |
| 8 | as 4 with `state` that has no `~` | 403 "Sign-in could not be verified" |
| 9 | the Google `STATE`/`NONCE` sent to `$API_LINKEDIN/oauth/linkedin/continue` | 403 "Sign-in could not be verified" |
| 10 | as 4, more than 10 minutes after issuing | 403 "Sign-in could not be verified" |
| 11 | `continue` with `state` or `nonce` omitted or sent as `""` | 400 "Missing param: state" / "Missing param: nonce" |
| 12 | Remove `OAUTH_STATE_SECRET` (test workspace only) and call `init` | 500 "OAuth state signing is not configured." |

Example for row 4:

```sh
curl -s -X POST "$API_GOOGLE/oauth/google/continue" -H 'Content-Type: application/json' \
  -d "{\"code\":\"fake\",\"state\":\"$STATE\",\"nonce\":\"$NONCE\"}"
```

Repeat rows 1–11 against LinkedIn. For row 4, expect "Sign-in with LinkedIn failed".

### Real browser tests

1. **Normal sign-in** for each provider. Before you implement the integration boundary, expect
   "Application authentication is not implemented." After, expect your session.
2. **Cancel** at the provider: the callback shows "cancelled or denied" and does not call Xano.
3. **Cross-browser link:** start sign-in in browser A, stop at the callback (copy the URL before it
   loads, for example by blocking the callback page or reading the provider's redirect), and open that
   URL in browser B. Browser B should show "Sign-in expired" and not call Xano.
4. **Reload the callback:** the first load already removed `code` and `state` from the URL and deleted
   the nonce, so the reload shows "Invalid sign-in response. Please try again." and makes no Xano call.
5. **www vs apex:** start on one and get redirected to the other; expect "Sign-in expired". Fix your
   redirect URI or hosting so both use the same origin.
6. After implementing your logic: existing linked user, new user (if sign-up is allowed), blocked user,
   and an email that already exists locally but is unverified.

In test 3, do **not** let the callback finish in browser A first: a provider code works only once.
