defmodule BlogEngine.Repo.Migrations.AddTimeLogs do
  use Ecto.Migration

  def change do
    alter table("devices") do
      add :record_wifi_time, :boolean, default: false
    end
  end
end
