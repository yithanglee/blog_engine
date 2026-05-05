defmodule BlogEngine.Repo.Migrations.AddTncToOrganizations do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add :tnc, :binary
    end
  end
end
