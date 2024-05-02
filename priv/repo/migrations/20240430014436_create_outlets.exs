defmodule BlogEngine.Repo.Migrations.CreateOutlets do
  use Ecto.Migration

  def change do
    create table(:outlets) do
      add :name, :string
      add :address, :string
      add :is_blocked, :boolean, default: false, null: false
      add :block_reason, :string

      timestamps()
    end

  end
end
