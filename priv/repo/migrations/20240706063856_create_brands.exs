defmodule BlogEngine.Repo.Migrations.CreateBrands do
  use Ecto.Migration

  def change do
    create table(:brands) do
      add :name, :string
      add :desc, :binary
      add :short_desc, :binary
      add :img_url, :string

      timestamps()
    end

  end
end
