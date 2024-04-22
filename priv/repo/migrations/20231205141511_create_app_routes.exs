defmodule BlogEngine.Repo.Migrations.CreateAppRoutes do
  use Ecto.Migration

  def change do
    create table(:app_routes) do
      add :name, :string
      add :icon, :string
      add :route, :string
      add :parent_id, :integer
      add :desc, :string
      add :can_get, :boolean, default: false, null: false
      add :can_post, :boolean, default: false, null: false

      timestamps()
    end

  end
end
