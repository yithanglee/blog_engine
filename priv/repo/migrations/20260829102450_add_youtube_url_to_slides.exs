defmodule BlogEngine.Repo.Migrations.AddYoutubeUrlToSlides do
  use Ecto.Migration

  def change do
    alter table("slides") do
      add :youtube_url, :string
    end
  end
end
