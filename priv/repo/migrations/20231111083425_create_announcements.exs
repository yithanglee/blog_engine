defmodule BlogEngine.Repo.Migrations.CreateAnnouncements do
  use Ecto.Migration

  def change do
    create table(:announcements) do
      add :content, :binary
      add :title, :string
      add :ctitle, :string
      add :subtitle, :string
      add :csubtitle, :string
      add :ccontent, :binary
      add :category, :string
      add :author, :string
      add :img_url, :string

      timestamps()
    end

  end
end
