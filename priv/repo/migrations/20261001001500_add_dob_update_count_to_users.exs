defmodule BlogEngine.Repo.Migrations.AddDobUpdateCountToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :dob_update_count, :integer, default: 0, null: false
    end
  end
end
