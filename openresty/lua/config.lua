local M = {}
function M.oidc_opts()
  local d = os.getenv("AUTH0_DOMAIN")
  local host = os.getenv("PUBLIC_HOST")
  return {
    discovery = "https://"..d.."/.well-known/openid-configuration",
    client_id = os.getenv("AUTH0_CLIENT_ID"),
    client_secret = os.getenv("AUTH0_CLIENT_SECRET"),
    redirect_uri = "https://"..host.."/callback",
    scope = "openid email profile",
    ssl_verify = "yes",
    session_contents = { id_token=true, access_token=true, user=true },
    renew_access_token_on_expiry = true,
  }
end
function M.sites()
  return {
    ["app1.example.internal"] = {
      upstream = "http://app1:8080",
      driver   = "site_drivers.html_form_example",
      login = { path="/login", method="POST" },
      cookie_ttl = 3600
    }
  }
end
return M
