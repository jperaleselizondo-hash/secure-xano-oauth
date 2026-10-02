// Verifies a signed OAuth state against the nonce held in the browser's sessionStorage.
//
// Passes only if the signature is valid, the state was issued for this provider, it has not expired,
// and the SHA-256 of the nonce sent by the browser matches the hash bound into the state.
// Call it BEFORE exchanging the authorization code, so a rejected callback never consumes the code.
// Every failure returns the same generic 403, so a caller cannot tell which check failed.
function oauth_state_verify {
  input {
    // Provider whose callback is being handled
    text provider filters=trim

    // The state returned by the provider on the callback URL
    text state filters=trim

    // The nonce read from the browser's sessionStorage (never from the URL)
    text nonce filters=trim
  }

  stack {
    precondition ($env.OAUTH_STATE_SECRET != null && ($env.OAUTH_STATE_SECRET|strlen) >= 64) {
      error = "OAuth state signing is not configured."
    }

    precondition ($input.state != "" && ("/^[0-9a-f]{64}$/"|regex_matches:$input.nonce)) {
      error_type = "accessdenied"
      error = "Sign-in could not be verified. Please try again."
    }

    var $state_parts {
      value = $input.state|split:"~"
    }

    // Check the signature before decoding anything from the state
    precondition (($state_parts|count) == 2 && ($state_parts[0]|hmac_sha256:$env.OAUTH_STATE_SECRET) == $state_parts[1]) {
      error_type = "accessdenied"
      error = "Sign-in could not be verified. Please try again."
    }

    var $state_claims {
      value = $state_parts[0]
        |base64_decode_urlsafe
        |json_decode
    }

    precondition ($state_claims.p == $input.provider && $state_claims.exp > now && $state_claims.bh == ($input.nonce|sha256)) {
      error_type = "accessdenied"
      error = "Sign-in could not be verified. Please try again."
    }
  }

  response = true
}
