CREATE TABLE IF NOT EXISTS user_site_credentials (
  user_sub     TEXT NOT NULL,
  site_host    TEXT NOT NULL,
  enc_username BYTEA NOT NULL,
  iv_username  BYTEA NOT NULL,
  enc_password BYTEA NOT NULL,
  iv_password  BYTEA NOT NULL,
  key_version  INT  NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_sub, site_host)
);
CREATE INDEX IF NOT EXISTS idx_user_site_credentials_site ON user_site_credentials (site_host);
