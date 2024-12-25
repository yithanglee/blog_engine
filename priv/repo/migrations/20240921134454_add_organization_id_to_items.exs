defmodule BlogEngine.Repo.Migrations.AddOrganizationIdToItems do
  use Ecto.Migration

  def change do
 alter table("items") do
      add :organization_id, references(:organizations)
    end


    alter table("staffs") do
      add :organization_id, references(:organizations)
    end
  end
end
