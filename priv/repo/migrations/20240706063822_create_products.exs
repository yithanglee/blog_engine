defmodule BlogEngine.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :name, :string
      add :short_desc, :binary
      add :desc, :binary
      add :category_id, :integer
      add :brand_id, :integer
      add :img_url, :string
      add :img_url2, :string
      add :img_url3, :string
      add :img_url4, :string
      add :img_url5, :string
      add :img_url6, :string
      add :balance, :integer

      timestamps()
    end

  end
end
