# OpenResty Auth0 Legacy SSO Proxy

OpenResty (Nginx + Lua) を使用したエンタープライズ向け Auth0 SSO リバースプロキシ。
レガシーアプリケーションに対して透過的なSSO環境を提供します。

## 🎯 主な機能

- **Auth0 OIDC 統合** - モダンなOpenID Connect認証フロー
- **レガシー認証代行** - 既存アプリへの自動ログイン
- **透過的プロキシ** - アプリケーション無修正でSSO化
- **暗号化資格情報管理** - AES-256-GCMによる安全な認証情報保存
- **マルチテナント対応** - サイト別の認証設定
- **AWS ALB対応** - SSL終端・ヘルスチェック完全対応

## 🏗️ アーキテクチャ

```
[User] → [ALB/LB] → [OpenResty Proxy] → [Legacy Apps]
                            ↓
                    [Auth0] [PostgreSQL] [Redis]
```

## 📁 プロジェクト構成

```
openresty-auth0-lagacy-sso-proxy/
├── openresty/                    # OpenResty設定
│   ├── nginx.conf               # メイン設定
│   ├── conf.d/
│   │   ├── default.conf         # サーバー設定
│   │   └── app-example.conf     # アプリ別設定例
│   └── lua/                     # Luaモジュール
│       ├── config.lua           # 設定管理
│       ├── access_guard.lua     # 認証ガード
│       ├── cred_handler.lua     # 資格情報UI
│       ├── cred_store.lua       # DB操作
│       ├── kms_client.lua       # 暗号化
│       └── site_drivers/        # サイト別ドライバー
│           └── html_form_example.lua
├── db/migrations/               # データベーススキーマ
├── docker-compose.yml           # 開発環境
├── Dockerfile                   # コンテナイメージ
└── .env.example                # 環境変数テンプレート
```

## 🚀 クイックスタート

### 1. 環境設定

```bash
cp .env.example .env
# .envファイルを編集してAuth0設定を入力
```

### 2. 開発環境起動

```bash
docker-compose up -d
```

### 3. アクセス

- **メインアクセス**: http://localhost:8080
- **資格情報管理**: http://localhost:8080/__cred/?site=app1.example.internal
- **ヘルスチェック**: http://localhost:8080/healthz

## ⚙️ 設定

### Auth0設定

```bash
AUTH0_DOMAIN=yourtenant.auth0.com
AUTH0_CLIENT_ID=your_client_id
AUTH0_CLIENT_SECRET=your_client_secret
PUBLIC_HOST=your-domain.com
```

### サイト定義 (`openresty/lua/config.lua`)

```lua
function M.sites()
  return {
    ["app1.example.com"] = {
      upstream = "http://app1-backend:8080",
      driver = "site_drivers.html_form_example",
      login = { path="/login", method="POST" },
      cookie_ttl = 3600
    }
  }
end
```

### サイトドライバー実装

各レガシーアプリケーション用のログインドライバーを `openresty/lua/site_drivers/` に実装:

```lua
local M = {}

function M.prelogin(http_client, base_url)
  -- CSRFトークン取得など前処理
end

function M.build_payload(username, password, prelogin_data)
  -- ログインフォーム構築
end

function M.success(response)
  -- ログイン成功判定
end

function M.session_cookies(response)
  -- セッションCookie抽出
end

return M
```

## 🔄 アクセスフロー

### 1. 初回アクセス（未認証ユーザー）

```
[Client] → [ALB] → [OpenResty] → [Auth0]
```

**処理の流れ:**
1. `https://app1.example.com/` にアクセス
2. ALBがHTTPS終端、OpenRestyに転送
3. `access_by_lua_block` で認証チェック → **未認証**
4. Auth0にリダイレクト

### 2. Auth0認証後のコールバック

```
[Auth0] → [Client] → [ALB] → [OpenResty]
```

**処理の流れ:**
1. Auth0認証完了後コールバックURL (`/callback`) に戻る
2. JWTトークン検証、ユーザー情報取得
3. セッション作成
4. 元のURL（`https://app1.example.com/`）にリダイレクト

### 3. 認証済みアクセス（レガシーログイン）

```
[Client] → [ALB] → [OpenResty] → [Legacy App]
```

**access_guard.luaの処理:**
```lua
-- 1. OIDC認証確認 ✓
-- 2. サイト設定取得（config.lua）
-- 3. cookiejarから既存セッション確認
if not existing_cookie then
  -- 4. 資格情報取得（PostgreSQL）
  -- 5. サイトドライバーでレガシーログイン実行
  -- 6. セッションCookie保存（メモリ）
end
-- 7. upstreamへプロキシ（認証済み状態）
```

### 4. 資格情報管理

```
https://proxy.example.com/__cred/?site=app1.example.com
```

1. OIDC認証確認
2. 対象サイトの認証情報フォーム表示
3. ユーザーが認証情報入力・保存
4. AES-256-GCM暗号化でPostgreSQLに保存

### 5. 2回目以降のアクセス（高速パス）

```
[Client] → [ALB] → [OpenResty] → [Legacy App]
```

1. OIDC認証確認 ✓
2. cookiejarから保存済みセッション取得 ✓
3. セッションCookieを付与して直接プロキシ

## 🔒 セキュリティ

- **暗号化**: AES-256-GCM + エンベロープ暗号化
- **認証**: OpenID Connect (Auth0)
- **セッション**: 署名付きJWTセッション
- **通信**: HTTPS強制 (ALB終端)
- **認可**: ユーザー・サイト単位のアクセス制御

## 🛠️ 本番デプロイ

### 環境変数

```bash
# 本番環境
ENVIRONMENT=production
AUTH0_DOMAIN=company.auth0.com
PUBLIC_HOST=sso.company.com
PGHOST=rds-endpoint
REDIS_HOST=elasticache-endpoint
DATA_KEY_VERSION=1
DATA_KEY_v1=<32バイトのランダムキー>
```

## 🧪 テスト

```bash
# 単体テスト
docker-compose exec openresty resty test/

# 統合テスト
curl -i http://localhost:8080/healthz
curl -i http://localhost:8080/ # Auth0リダイレクト確認
```
