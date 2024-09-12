defmodule BlogEngine.Repo.Migrations.CreatePages do
  use Ecto.Migration

  def change do
    create table(:pages) do
      add :name, :string
      add :subtitle, :string
      add :content, :binary
      add :img_url, :string
      add :route_name, :string
      add :file_name, :string

      timestamps()
    end

  end
end
