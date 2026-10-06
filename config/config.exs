# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :blog_engine,
  ecto_repos: [BlogEngine.Repo]

# FCM profile keys match folder names under priv/static/firebase/<profile>/
config :blog_engine, :fcm,
  default_profile: "main",
  member_profile: System.get_env("FCM_MEMBER_PROFILE") || "hub"

# Google OAuth ID token audiences (Web + Android client IDs, comma-separated)
config :blog_engine,
       :google_client_ids,
       System.get_env("GOOGLE_CLIENT_IDS") ||
         "271185094773-gj5f1avv0n0qh0ia4v3re95n8ddh1bsp.apps.googleusercontent.com,271185094773-8egdmqv0ku7qrtkfmgn8jubomoarg0k4.apps.googleusercontent.com"

# Configures the endpoint
config :blog_engine, BlogEngineWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "4vvlxoQtn0Dd2irSRa4d8QUAmkBWr+SaF8x3MbsR6CXEcQga/Vy5uvh01T9YlL89",
  render_errors: [view: BlogEngineWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: BlogEngine.PubSub,
  live_view: [signing_salt: "eHS1OdsC"]

config :blog_engine, BlogEngine.Repo,
  username: "postgres",
  password: "postgres",
  database: System.get_env("DB_NAME"),
  hostname: System.get_env("DB_HOST"),
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :blue_potion,
  otp_app: "BlogEngine",
  repo: BlogEngine.Repo,
  contexts: ["Settings"],
  project: %{name: "BlogEngine", alias_name: "blog_engine", vsn: "0.1.0", sname: "blog_engine"},
  server: %{
    url: "139.162.60.209",
    db_url: "127.0.0.1",
    username: "ubuntu",
    key: System.get_env("SERVER_KEY"),
    domain_name: "localhost"
  },
  stag_server: %{
    url: "192.53.172.101",
    db_url: "127.0.0.1",
    username: "ubuntu",
    key: System.get_env("STAG_SERVER_KEY"),
    domain_name: "localhost"
  }

config :blog_engine, BlogEngine.Scheduler,
  jobs: [
    {"*/5 * * * *", {BlogEngine, :check_online, ["1"]}},
    {"0 0 * * *", {BlogEngine.Settings, :trigger_birthday_vouchers, []}}
  ]

# Application.get_env(:blog_engine, :cloridge)[:key]
config :blog_engine, :cloridge,
  key: System.get_env("CLORIDGE_KEY"),
  secret: System.get_env("CLORIDGE_SECRET")

# Same ElasticMQ queue WebhookEdge publishes to (SQS_QUEUE_URL).
config :blog_engine, :sqs,
  queue_url: System.get_env("SQS_QUEUE_URL") || "http://localhost:9324/queue/queue1",
  queue_url2: System.get_env("SQS_QUEUE_URL2") || "http://10.8.0.2:9324/queue/queue2",
  host2: System.get_env("SQS_HOST2") || "10.8.0.2",
  port2: System.get_env("SQS_PORT2") || "9324",
  host: System.get_env("SQS_HOST") || "localhost",
  port: System.get_env("SQS_PORT") || "9324",
  scheme: System.get_env("SQS_SCHEME") || "http://",
  region: System.get_env("AWS_REGION") || "elasticmq",
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID") || "x",
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY") || "x"

config :blog_engine, :start_queue, true

# Trailing slash required. Example: http://localhost:4010/
config :blog_engine, :webhook_edge_url, System.get_env("WEBHOOK_EDGE_URL")

config :sentry,
  environment_name: Mix.env(),
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
