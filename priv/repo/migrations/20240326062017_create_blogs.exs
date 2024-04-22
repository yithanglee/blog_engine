defmodule BlogEngine.Repo.Migrations.CreateBlogs do
  use Ecto.Migration

  def change do
    create table(:blogs) do
      add :title, :string
      add :excerpt, :string
      add :thumbnail_img, :string
      add :img_url, :string
      add :category_id, :integer
      add :content, :binary

      timestamps()
    end

  end
end
