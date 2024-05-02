defmodule BlogEngine.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items) do
      add :name, :string
      add :price, :float
      add :desc, :binary
      add :image_url, :string

      timestamps()
    end

  end
end
