defmodule BlogEngine.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    source =
      {:service_account,
       File.read!("#{Application.app_dir(:blog_engine) <> "/priv/static"}/service-account.json")
       |> Jason.decode!()}

    children = [
      {Goth, name: BlogEngine.Goth, source: source},
      # {BlogEngine.Queue, []},
      BlogEngine.Repo,
      # Start the Telemetry supervisor
      BlogEngineWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: BlogEngine.PubSub},
      # Start the Endpoint (http/https)
      BlogEngineWeb.Endpoint,
      BlogEngine.Scheduler
      # Start a worker by calling: BlogEngine.Worker.start_link(arg)
      # {BlogEngine.Worker, arg}
    ]

    {:ok, pid} = Agent.start_link(fn -> %{} end)
    Process.register(pid, :kv)
    path = File.cwd!() <> "/media"

    if File.exists?(path) == false do
      File.mkdir(File.cwd!() <> "/media")
    end

    File.rm_rf("#{Application.app_dir(:blog_engine)}/priv/static/images/uploads")

    File.ln_s(
      "#{File.cwd!()}/media/",
      "#{Application.app_dir(:blog_engine)}/priv/static/images/uploads"
    )

    DeviceTracker.start_link()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BlogEngine.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    BlogEngineWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
