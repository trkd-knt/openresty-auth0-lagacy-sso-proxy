local openssl_cipher = require "resty.openssl.cipher"
local rand = require "resty.random"
local M = {}

-- 簡易鍵管理（PoC）：環境変数 DATA_KEY_v{n} から取得
local CURRENT_VER = tonumber(os.getenv("DATA_KEY_VERSION") or "1")

local function key_by_version(ver)
  local hex = os.getenv("DATA_KEY_v"..ver) -- 32 bytes hex (64 chars)
  assert(hex and #hex == 64, "DATA_KEY_v"..ver.." not set or invalid length")
  return (hex:gsub("..", function(cc) return string.char(tonumber(cc,16)) end))
end

function M.current_key()
  return CURRENT_VER, key_by_version(CURRENT_VER)
end

function M.get_data_key(ver)
  return key_by_version(ver)
end

function M.encrypt(key, plaintext)
  local iv = rand.bytes(12, true)
  local c = assert(openssl_cipher.new("aes-256-gcm"))
  assert(c:init(true, key, iv))
  local ct = assert(c:update(plaintext)) .. assert(c:final())
  local tag = assert(c:get_tag(16))
  return iv, (iv .. ct .. tag)   -- PoC：まとめて保存（IVは別列にも持っているので両方で冗長）
end

function M.decrypt(key, blob, iv_col)
  local iv = iv_col
  local ct = string.sub(blob, 13, #blob - 16)
  local tag = string.sub(blob, #blob - 15)
  local c = assert(openssl_cipher.new("aes-256-gcm"))
  assert(c:init(false, key, iv))
  assert(c:set_tag(tag))
  local pt = assert(c:update(ct)) .. assert(c:final())
  return pt
end

return M
