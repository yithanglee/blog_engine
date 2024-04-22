defmodule BlogEngine.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories) do
      add :name, :string
      add :desc, :string
      add :parent_id, :integer

      timestamps()
    end

  end
end
