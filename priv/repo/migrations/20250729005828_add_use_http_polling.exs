defmodule BlogEngine.Repo.Migrations.AddUseHttpPolling do
  use Ecto.Migration

  def change do
    alter table("devices") do
      add :use_http_polling, :boolean, default: false
    end
  end
end
