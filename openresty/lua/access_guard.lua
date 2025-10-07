local oidc  = require "resty.openidc"
local http  = require "resty.http"
local cjson = require "cjson.safe"
local cred  = require "cred_store"

-- ここでは SITES / OIDC_OPTS は config.lua -> init_by_lua_block で package.loaded に格納済み想定
local opts  = package.loaded["OIDC_OPTS"]
local sites = package.loaded["SITES"]

-- 認証（未ログインならAuth0へ）
local res, err = oidc.authenticate(opts)
if err then
  ngx.log(ngx.ERR, "OIDC authenticate failed: ", err)
  return ngx.exit(401)
end

local user   = res.user or {}
local user_id = user.sub or user.email or user.preferred_username
if not user_id then return ngx.exit(403) end

local host = ngx.var.host
local site = sites[host]
if not site then
  ngx.log(ngx.ERR, "unknown site for host: ", host)
  return ngx.exit(502)
end

-- 既に上流Cookie（ユーザ×サイト）を保持していれば注入してプロキシ
local jar = ngx.shared.cookiejar
local jar_key = user_id .. "|" .. host
local cookie_str = jar:get(jar_key)

if not cookie_str then
  -- 資格情報を取得（なければ登録画面へ）
  local login_cred, cerr = cred.fetch(user_id, host)
  if cerr == "not_found" or not login_cred then
    return ngx.redirect("/__cred/?site="..ngx.escape_uri(host).."&return="..ngx.escape_uri(ngx.var.request_uri))
  elseif cerr then
    ngx.log(ngx.ERR, "cred fetch error: ", cerr); return ngx.exit(500)
  end

  -- ログイン前処理（任意CSRFやCookie取得）
  local hc = http.new(); hc:set_timeout(5000)
  local driver = require(site.driver or "site_drivers.html_form_example")
  local base   = site.upstream

  local pre, perr = driver.prelogin(hc, base)
  if perr then ngx.log(ngx.ERR, "prelogin error: ", perr); return ngx.exit(502) end

  -- 送信ペイロードを作ってフォームPOST
  local body, ctype = driver.build_payload(login_cred.username, login_cred.password, pre)
  local r, rerr = hc:request_uri(base .. site.login.path, {
    method  = site.login.method or "POST",
    body    = body,
    headers = { ["Content-Type"] = ctype or "application/x-www-form-urlencoded", ["Host"]=host },
    keepalive = false,
  })
  if not r or r.status >= 400 then
    ngx.log(ngx.ERR, "login POST failed: ", rerr or (r and r.status))
    return ngx.exit(502)
  end

  if not driver.success(r) then
    ngx.log(ngx.WARN, "login not successful; status=", r.status)
    return ngx.exit(502)
  end

  cookie_str = driver.session_cookies(r)
  if not cookie_str then
    ngx.log(ngx.ERR, "no Set-Cookie returned from upstream login")
    return ngx.exit(502)
  end
  jar:set(jar_key, cookie_str, site.cookie_ttl or 3600)
end

-- 上流を指示（変数proxy_pass）
ngx.var.upstream = site.upstream

-- Cookie注入 & SSO利用者ヘッダ（任意）
ngx.req.set_header("Cookie", cookie_str)
ngx.req.set_header("X-SSO-User", user_id)
ngx.req.set_header("X-SSO-Email", user.email or "")
-- 以降は nginx.conf の proxy_pass $upstream によってフォワード
