# OpenResty (Ubuntu/Debian)
FROM openresty/openresty:jammy

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      wget \
  && rm -rf /var/lib/apt/lists/* \
  && update-ca-certificates

RUN useradd --system --no-create-home --shell /bin/false nginx
RUN mkdir -p /usr/local/openresty/nginx/logs /var/cache/nginx /var/run \
 && chown -R nginx:nginx /usr/local/openresty/nginx /var/cache/nginx /var/run

# LuaRocks packages
RUN luarocks install lua-resty-openidc \
 && luarocks install lua-resty-session \
 && luarocks install lua-resty-http \
 && luarocks install lua-resty-redis \
 && luarocks install lua-resty-postgres

# ログディレクトリの作成
RUN mkdir -p /usr/local/openresty/nginx/conf/conf.d \
             /usr/local/openresty/nginx/lua

# 設定/コードのコピー
COPY openresty/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY openresty/conf.d/   /usr/local/openresty/nginx/conf/conf.d/
COPY openresty/lua/      /usr/local/openresty/nginx/lua/

# パーミッション
RUN find /usr/local/openresty/nginx/conf -type d -exec chmod 755 {} \; \
 && find /usr/local/openresty/nginx/conf -type f -exec chmod 644 {} \; \
 && find /usr/local/openresty/nginx/lua  -type d -exec chmod 755 {} \; \
 && find /usr/local/openresty/nginx/lua  -type f -exec chmod 644 {} \;

# 非ルート
USER nginx

EXPOSE 8080

# HEALTHCHECK
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD wget -qO- http://127.0.0.1/ || exit 1

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
