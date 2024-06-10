defmodule BlogEngine.Repo.Migrations.CreateDeviceTimeLogs do
  use Ecto.Migration

  def change do
    create table(:device_time_logs) do
      add :device_id, :integer

      timestamps()
    end

  end
end
