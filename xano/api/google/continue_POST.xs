// Callback step of Google sign-in. Order matters:
//   1. Verify the signed state against the browser's nonce BEFORE touching the authorization code,
//      so a forged or cross-browser callback is refused and the code is never consumed.
//   2. Exchange the code and fetch the verified Google identity.
//   3. Hand that identity to YOUR application's authentication logic.
// This endpoint fails closed: until you implement step 3 it returns an error, never an identity.
query "oauth/google/continue" verb=POST {
  api_group = "google-oauth"

  input {
    // Authorization code from the callback URL
    text code filters=trim

    // State from the callback URL
    text state filters=trim

    // Nonce read from the browser's sessionStorage, never from the URL
    text nonce filters=trim
  }

  stack {
    function.run oauth_state_verify {
      input = {provider: "google", state: $input.state, nonce: $input.nonce}
    } as $state_verified

    function.run google_oauth_get_identity {
      input = {code: $input.code}
    } as $identity

    // ==========================================================================================
    // YOUR APPLICATION AUTHENTICATION LOGIC HERE
    // ------------------------------------------------------------------------------------------
    // $identity = {provider, provider_user_id, email, email_verified, name}
    //
    // $identity is the provider's verified identity. It is NOT an application session, and it
    // must never be returned to the browser as proof of sign-in. Replace this block with your
    // own logic, for example:
    //   - look up the user linked to (provider, provider_user_id);
    //   - never attach a provider identity to an existing user by email alone unless both the
    //     provider (email_verified) and your application have verified that email;
    //   - create a user on first sign-in only if your application allows sign-up;
    //   - refuse banned, deactivated or otherwise blocked users;
    //   - issue your own session (for example security.create_auth_token) and set $app_session
    //     to the response your frontend expects.
    // ==========================================================================================
    var $app_session {
      value = null
    }

    // Fails closed until the block above sets $app_session
    precondition ($app_session != null) {
      error = "Application authentication is not implemented."
    }
  }

  response = $app_session
}
