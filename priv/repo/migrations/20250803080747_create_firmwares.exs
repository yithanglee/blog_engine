defmodule BlogEngine.Repo.Migrations.CreateFirmwares do
  use Ecto.Migration

  def change do
    create table(:firmwares) do
      add :name, :string
      add :version, :string
      add :metadata, :binary
      add :url, :string

      timestamps()
    end

  end
end
