local M = {}
function M.prelogin(hc, base)
  local r = hc:request_uri(base.."/login", { method="GET", keepalive=false })
  if not r or r.status ~= 200 then return nil, "login page failed" end
  local m = ngx.re.match(r.body, [[name="authenticity_token"\s+value="([^"]+)"]], "jo")
  return { csrf = m and m[1], cookies = r.headers["Set-Cookie"] }
end
function M.build_payload(user, pass, t)
  local args = {
    ["username"] = user,
    ["password"] = pass,
  }
  if t and t.csrf then args["authenticity_token"] = t.csrf end
  return ngx.encode_args(args), "application/x-www-form-urlencoded"
end
function M.success(res)
  return (res.status == 302 and res.headers["Set-Cookie"]) or (res.headers["Set-Cookie"] and res.headers["Set-Cookie"]:find("SESSION",1,true))
end
function M.session_cookies(res)
  return res.headers["Set-Cookie"]
end
return M
