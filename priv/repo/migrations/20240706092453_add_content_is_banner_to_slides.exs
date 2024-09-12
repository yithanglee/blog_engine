defmodule BlogEngine.Repo.Migrations.AddContentIsBannerToSlides do
  use Ecto.Migration

  def change do
    alter table("slides") do
      add :content, :binary
      add :is_banner, :boolean, default: false
    end
  end
end
