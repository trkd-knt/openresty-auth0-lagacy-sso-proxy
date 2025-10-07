local openidc = require("resty.openidc")
local session = require("resty.session")
local cjson = require("cjson")

local _M = {}

-- Auth0設定（環境変数から取得）
local function get_auth0_config()
    return {
        discovery = os.getenv("AUTH0_DISCOVERY_URL") or "https://YOUR_DOMAIN.auth0.com/.well-known/openid-configuration",
        client_id = os.getenv("AUTH0_CLIENT_ID") or "YOUR_CLIENT_ID",
        client_secret = os.getenv("AUTH0_CLIENT_SECRET") or "YOUR_CLIENT_SECRET",
        redirect_uri = os.getenv("AUTH0_REDIRECT_URI") or "https://YOUR_DOMAIN/auth/callback",
        logout_path = "/auth/logout",
        redirect_after_logout_uri = os.getenv("AUTH0_LOGOUT_REDIRECT_URI") or "https://YOUR_DOMAIN/",
        scope = "openid profile email",
        session_contents = {
            access_token = true,
            id_token = true,
            user = true
        },
        -- セッション設定
        session = {
            secret = os.getenv("SESSION_SECRET") or "change-this-secret-in-production",
            cookie = {
                lifetime = 3600, -- 1時間
                path = "/",
                domain = nil,
                secure = true,
                httponly = true,
                samesite = "Lax"
            }
        },
        -- SSL検証
        ssl_verify = "yes",
        -- タイムアウト設定
        timeout = 10000,
        -- レスポンスモード
        response_mode = "query"
    }
end

-- 認証チェック
function _M.authenticate()
    local config = get_auth0_config()
    
    -- OpenIDCで認証
    local res, err = openidc.authenticate(config)
    
    if err then
        ngx.log(ngx.ERR, "Authentication error: ", err)
        ngx.status = 500
        ngx.say("Authentication failed: " .. err)
        ngx.exit(500)
    end
    
    if not res then
        ngx.log(ngx.ERR, "Authentication failed: no response")
        ngx.status = 401
        ngx.say("Authentication required")
        ngx.exit(401)
    end
    
    -- 認証成功時、ユーザー情報をヘッダーに設定
    if res.user then
        ngx.req.set_header("X-User-ID", res.user.sub or "")
        ngx.req.set_header("X-User-Email", res.user.email or "")
        ngx.req.set_header("X-User-Name", res.user.name or "")
        
        -- ログに記録
        ngx.log(ngx.INFO, "User authenticated: ", res.user.email or res.user.sub)
    end
    
    return res
end

-- ログアウト処理
function _M.logout()
    local config = get_auth0_config()
    
    -- セッション削除
    local sess = session.new()
    sess:destroy()
    
    -- Auth0ログアウトURLへリダイレクト
    local logout_url = string.format(
        "%s/v2/logout?client_id=%s&returnTo=%s",
        string.gsub(config.discovery, "/.well%-known/openid%-configuration", ""),
        config.client_id,
        ngx.escape_uri(config.redirect_after_logout_uri)
    )
    
    ngx.log(ngx.INFO, "User logout, redirecting to: ", logout_url)
    return ngx.redirect(logout_url)
end

-- 認証状態確認
function _M.check_auth_status()
    local sess = session.open()
    if sess.present and sess.data.user then
        return true, sess.data
    end
    return false, nil
end

-- ユーザー情報取得
function _M.get_user_info()
    local authenticated, session_data = _M.check_auth_status()
    if authenticated and session_data.user then
        return session_data.user
    end
    return nil
end

return _M