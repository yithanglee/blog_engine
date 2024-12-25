defmodule BlogEngine.Repo.Migrations.AddOrganizationId do
  use Ecto.Migration

  def change do
    alter table("users") do
      add :organization_id, references(:organizations)
    end
    alter table("outlets") do
      add :organization_id, references(:organizations)
    end

    alter table("sales") do
      add :organization_id, references(:organizations)
    end


    alter table("devices") do
      add :organization_id, references(:organizations)
    end
  end
end
