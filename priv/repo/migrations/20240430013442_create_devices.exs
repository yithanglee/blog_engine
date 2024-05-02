defmodule BlogEngine.Repo.Migrations.CreateDevices do
  use Ecto.Migration

  def change do
    create table(:devices) do
      add :name, :string
      add :short_desc, :string
      add :is_active, :boolean, default: false, null: false
      add :is_suspended, :boolean, default: false, null: false

      timestamps()
    end

  end
end
