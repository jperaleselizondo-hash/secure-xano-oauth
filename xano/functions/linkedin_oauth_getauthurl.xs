// Builds the LinkedIn authorization URL ("Sign In with LinkedIn using OpenID Connect").
// The redirect URI comes from the server environment, never from the client, and must exactly match
// an authorized redirect URL of your app in the LinkedIn developer portal.
function linkedin_oauth_getauthurl {
  input {
    // Signed state from oauth_state_issue
    text state filters=trim
  }

  stack {
    precondition ($env.LINKEDIN_CLIENT_ID != null && $env.LINKEDIN_CLIENT_ID != "" && $env.LINKEDIN_REDIRECT_URI != null && $env.LINKEDIN_REDIRECT_URI != "") {
      error = "LinkedIn sign-in is not configured."
    }

    precondition ($input.state != "") {
      error_type = "inputerror"
      error = "Invalid sign-in request. Please try again."
    }

    var $auth_url {
      value = "https://www.linkedin.com/oauth/v2/authorization"
        |url_addarg:"response_type":"code"
        |url_addarg:"client_id":$env.LINKEDIN_CLIENT_ID
        |url_addarg:"redirect_uri":$env.LINKEDIN_REDIRECT_URI
        |url_addarg:"scope":"openid profile email"
        |url_addarg:"state":$input.state
    }
  }

  response = $auth_url
}
