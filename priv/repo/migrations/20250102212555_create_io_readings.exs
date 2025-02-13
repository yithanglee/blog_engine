defmodule BlogEngine.Repo.Migrations.CreateIoReadings do
  use Ecto.Migration

  def change do
    create table(:io_readings) do
      add :device_id, references(:devices)
      add :log, :binary
      add :is_processed, :boolean, default: false, null: false
      add :final_data, :string

      timestamps()
    end

  end
end
