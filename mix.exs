defmodule BlogEngine.MixProject do
  use Mix.Project

  def project do
    [
      app: :blog_engine,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {BlogEngine.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bamboo, "~> 2.2.0"},
      {:bamboo_phoenix, "~> 1.0"},
      {:bamboo_smtp, "~> 4.2.2"},
      {:broadway, "~> 1.0"},
      {:broadway_sqs, "~> 0.7"},
      {:blue_potion, "~> 0.1.2",
       override: true, git: "https://github.com/yithanglee/blue_potion"},
      {:cors_plug, "~> 1.0"},
      {:distillery, "~> 2.1"},
      {:mime, "~> 1.0"},
      {:phoenix, "~> 1.5.13"},
      {:phoenix_ecto, "~> 4.1"},
      {:ecto_sql, ">= 3.0.0 and < 3.5.0"},
      {:ecto, ">= 3.4.4 and < 3.4.5"},
      {:ecto_enum, "~> 1.4"},
      {:pdf_generator, ">=0.3.5"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.2"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:poison, "~> 3.0"},
      {:mogrify, "~> 0.9.1"},
      {:sweet_xml, "~> 0.7"},
      {:web_push_encryption, "~> 0.3"},
      {:timex, "~> 3.0"},
      {:quantum, "~> 2.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #     nodemon --config nodemon.json
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      esbuild: ["run", "esbuild_script"]
    ]
  end
end
