defmodule BlogEngine.Repo.Migrations.CreateRoleAppRoute do
  use Ecto.Migration

  def change do
    create table(:role_app_route) do
      add :role_id, :integer
      add :app_route_id, :integer

      timestamps()
    end

  end
end
