// Exchanges a LinkedIn authorization code and returns the verified provider identity.
//
// Call it only AFTER oauth_state_verify has passed. Provider tokens stay inside this function: the
// access token is used once for the OpenID Connect userinfo call and is never returned.
// Provider error details are not passed to the client.
//
// Returns {provider, provider_user_id, email, email_verified, name}. This is the provider's identity,
// not an application session.
function linkedin_oauth_get_identity {
  input {
    // Authorization code from the callback URL
    text code filters=trim
  }

  stack {
    precondition ($env.LINKEDIN_CLIENT_ID != null && $env.LINKEDIN_CLIENT_ID != "" && $env.LINKEDIN_CLIENT_SECRET != null && $env.LINKEDIN_CLIENT_SECRET != "" && $env.LINKEDIN_REDIRECT_URI != null && $env.LINKEDIN_REDIRECT_URI != "") {
      error = "LinkedIn sign-in is not configured."
    }

    precondition ($input.code != "") {
      error_type = "inputerror"
      error = "Invalid sign-in request. Please try again."
    }

    // Code exchange: credentials travel in a POST form body, never in a URL
    api.request {
      url = "https://www.linkedin.com/oauth/v2/accessToken"
      method = "POST"
      params = {}
        |set:"grant_type":"authorization_code"
        |set:"code":$input.code
        |set:"client_id":$env.LINKEDIN_CLIENT_ID
        |set:"client_secret":$env.LINKEDIN_CLIENT_SECRET
        |set:"redirect_uri":$env.LINKEDIN_REDIRECT_URI
      headers = ["Content-Type: application/x-www-form-urlencoded", "Accept: application/json"]
      timeout = 15
    } as $token_response

    precondition ($token_response.response.status == 200 && $token_response.response.result.access_token != null && $token_response.response.result.access_token != "") {
      error_type = "accessdenied"
      error = "Sign-in with LinkedIn failed. Please try again."
    }

    // OpenID Connect userinfo, with the access token in the Authorization header
    api.request {
      url = "https://api.linkedin.com/v2/userinfo"
      method = "GET"
      headers = ["Authorization: Bearer " ~ $token_response.response.result.access_token, "Accept: application/json"]
      timeout = 15
    } as $userinfo_response

    precondition ($userinfo_response.response.status == 200 && ($userinfo_response.response.result.sub|to_text) != "") {
      error_type = "accessdenied"
      error = "Sign-in with LinkedIn failed. Please try again."
    }

    var $identity {
      value = {
        provider        : "linkedin"
        provider_user_id: $userinfo_response.response.result.sub|to_text
        email           : $userinfo_response.response.result.email
        email_verified  : $userinfo_response.response.result.email_verified == true
        name            : $userinfo_response.response.result.name
      }
    }
  }

  response = $identity
}
