defmodule BlogEngine.Repo.Migrations.AddYoutubeUrlToSlides do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE slides ADD COLUMN IF NOT EXISTS youtube_url VARCHAR(255);")
  end

  def down do
    execute("ALTER TABLE slides DROP COLUMN IF EXISTS youtube_url;")
  end
end
