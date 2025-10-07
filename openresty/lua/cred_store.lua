local pg   = require "resty.postgres"
local kms  = require "kms_client"

local M = {}

function M.fetch(user_id, site)
  local db = pg:new(); db:set_timeout(3000)
  assert(db:connect{ host=os.getenv("PGHOST") or "postgres", port=5432, database=os.getenv("PGDATABASE") or "app", user=os.getenv("PGUSER") or "app", password=os.getenv("PGPASSWORD") or "app" })
  local res, err = db:query("SELECT enc_username, iv_username, enc_password, iv_password, key_version FROM user_site_credentials WHERE user_sub=$1 AND site_host=$2", {user_id, site})
  if err then return nil, err end
  if not res or #res == 0 then return nil, "not_found" end
  local row = res[1]
  local key = kms.get_data_key(tonumber(row.key_version))
  local username = kms.decrypt(key, row.enc_username, row.iv_username)
  local password = kms.decrypt(key, row.enc_password, row.iv_password)
  db:keepalive(1000, 10)
  return {username=username, password=password}
end

function M.put(user_id, site, username, password)
  local db = pg:new(); db:set_timeout(3000)
  assert(db:connect{ host=os.getenv("PGHOST") or "postgres", port=5432, database=os.getenv("PGDATABASE") or "app", user=os.getenv("PGUSER") or "app", password=os.getenv("PGPASSWORD") or "app" })
  local key_version, key = kms.current_key()
  local u_iv, u_ct = kms.encrypt(key, username)
  local p_iv, p_ct = kms.encrypt(key, password)
  local q = [[INSERT INTO user_site_credentials(user_sub, site_host, enc_username, iv_username, enc_password, iv_password, key_version)
              VALUES($1,$2,$3,$4,$5,$6,$7)
              ON CONFLICT(user_sub, site_host) DO UPDATE
              SET enc_username=$3, iv_username=$4, enc_password=$5, iv_password=$6, key_version=$7, updated_at=now()]]
  local ok, err = db:query(q, {user_id, site, u_ct, u_iv, p_ct, p_iv, key_version})
  if not ok then return false, err end
  db:keepalive(1000, 10)
  return true
end

return M
