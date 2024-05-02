defmodule BlogEngine.Repo.Migrations.CreateDeviceLogs do
  use Ecto.Migration

  def change do
    create table(:device_logs) do
      add :device_id, :integer
      add :uuid, :string
      add :remarks, :string

      timestamps()
    end

  end
end
