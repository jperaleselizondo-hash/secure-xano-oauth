// Builds the Google authorization URL (OAuth 2.0 authorization code flow with OpenID Connect scopes).
// The redirect URI comes from the server environment, never from the client, and must exactly match
// an authorized redirect URI of your OAuth client in the Google Cloud console.
function google_oauth_getauthurl {
  input {
    // Signed state from oauth_state_issue
    text state filters=trim
  }

  stack {
    precondition ($env.GOOGLE_CLIENT_ID != null && $env.GOOGLE_CLIENT_ID != "" && $env.GOOGLE_REDIRECT_URI != null && $env.GOOGLE_REDIRECT_URI != "") {
      error = "Google sign-in is not configured."
    }

    precondition ($input.state != "") {
      error_type = "inputerror"
      error = "Invalid sign-in request. Please try again."
    }

    var $auth_url {
      value = "https://accounts.google.com/o/oauth2/v2/auth"
        |url_addarg:"response_type":"code"
        |url_addarg:"client_id":$env.GOOGLE_CLIENT_ID
        |url_addarg:"redirect_uri":$env.GOOGLE_REDIRECT_URI
        |url_addarg:"scope":"openid email profile"
        |url_addarg:"state":$input.state
    }
  }

  response = $auth_url
}
