local cred  = require "cred_store"
local args  = ngx.req.get_uri_args()

if ngx.req.get_method() == "GET" then
  local site   = args.site or ""
  local ret    = args.return or "/"
  ngx.header.content_type = "text/html; charset=utf-8"
  ngx.say([[
  <html><body>
   <h3>初回ログイン情報の登録</h3>
   <form method="POST" action="/__cred/submit">
     <input type="hidden" name="site" value="]]..ngx.escape_uri(site)..[["/>
     <input type="hidden" name="return" value="]]..ngx.escape_uri(ret)..[["/>
     <div>ユーザID: <input name="username" required></div>
     <div>パスワード: <input name="password" type="password" required></div>
     <button type="submit">保存</button>
   </form>
  </body></html>]])
  return
end

-- POST /__cred/submit
if ngx.var.uri == "/__cred/submit" and ngx.req.get_method() == "POST" then
  ngx.req.read_body()
  local form = ngx.req.get_post_args()
  local site = form.site
  local ret  = form["return"] or "/"
  if not (form.username and form.password and site) then return ngx.exit(400) end

  -- SSOユーザ識別（OpenID Connect済み前提）
  local oidc = require "resty.openidc"
  local opts = package.loaded["OIDC_OPTS"]
  local res, err = oidc.authenticate(opts)
  if err then return ngx.exit(401) end
  local user_id = (res.user or {}).sub or res.user.email or res.user.preferred_username
  if not user_id then return ngx.exit(403) end

  local ok, cerr = cred.put(user_id, site, form.username, form.password)
  if not ok then ngx.log(ngx.ERR, "cred save error: ", cerr); return ngx.exit(500) end

  return ngx.redirect(ret, 303)
end

return ngx.exit(404)
