defmodule BlogEngine.Repo.Migrations.AddDeviceTimeLogsIndexes do
  use Ecto.Migration

  def change do
    # Optimizes queries filtered by device_id + inserted_at range (hourly/day/week/month aggregations)
    # Use IF NOT EXISTS semantics so migration doesn't fail if index was created manually (e.g. via DBeaver).
    create_if_not_exists index(:device_time_logs, [:device_id, :inserted_at],
                             name: :device_time_logs_device_id_inserted_at_index)
  end
end
