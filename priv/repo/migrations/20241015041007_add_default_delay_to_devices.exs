defmodule BlogEngine.Repo.Migrations.AddDefaultDelayToDevices do
  use Ecto.Migration

  def change do
    alter table("devices") do
      add :default_delay, :float, default: 0.1
    end
  end
end
