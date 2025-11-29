defmodule BlogEngine.Repo.Migrations.CreateFirmwareLogs do
  use Ecto.Migration

  def change do
    create table(:firmware_logs) do
      add :device_id, :integer
      add :action, :string
      add :version, :string

      timestamps()
    end

  end
end
