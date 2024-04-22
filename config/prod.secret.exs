# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
use Mix.Config

database_url =
  System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

config :blog_engine, BlogEngine.Repo,
  # ssl: true,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

config :blog_engine, BlogEngineWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: secret_key_base

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:
#
#     config :blog_engine, BlogEngineWeb.Endpoint, server: true
#
# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.
config :blog_engine, BlogEngineWeb.Endpoint, server: true

config :blog_engine, url: System.get_env("ENDPOINT_PROD")

config :blog_engine, :billplz,
  key: System.get_env("BILLPLZ_API_KEY_PROD"),
  endpoint: System.get_env("BILLPLZ_API_ENDPOINT_PROD"),
  callback: System.get_env("BILLPLZ_API_CALLBACK_URL_PROD")

config :blog_engine, BlogEngine.Mailer,
  adapter: Bamboo.SMTPAdapter,
  server: "smtp.zoho.com",
  hostname: "haho2u.com",
  # port: 25,
  port: 465,
  # or {:system, "SMTP_USERNAME"}
  username: "support@haho2u.com",
  # or {:system, "SMTP_PASSWORD"}
  password: "jakk@cT2",
  # can be `:always` or `:never`
  tls: :never,
  # or {:system, "ALLOWED_TLS_VERSIONS"} w/ comma separated values (e.g. "tlsv1.1,tlsv1.2")
  allowed_tls_versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"],
  tls_log_level: :error,
  # optional, can be `:verify_peer` or `:verify_none`
  tls_verify: :verify_none,
  # optional, path to the ca truststore
  # tls_cacertfile: "/somewhere/on/disk",
  # optional, DER-encoded trusted certificates
  # tls_cacerts: "…",
  # optional, tls certificate chain depth
  # tls_depth: 3,
  # optional, tls verification function
  # tls_verify_fun: {&:ssl_verify_hostname.verify_fun/3, check_hostname: "example.com"},
  # can be `true`
  ssl: true,
  retries: 1,
  # can be `true`
  no_mx_lookups: false,
  # can be `:always`. If your smtp relay requires authentication set it to `:always`.
  auth: :if_available
