defmodule BlogEngine.Repo.Migrations.CreateStoredMedias do
  use Ecto.Migration

  def change do
    create table(:stored_medias) do
      add :name, :string
      add :format, :string
      add :url, :string
      add :file_type, :string
      add :blog_id, :integer

      timestamps()
    end

  end
end
