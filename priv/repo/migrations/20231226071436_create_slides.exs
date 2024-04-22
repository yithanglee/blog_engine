defmodule BlogEngine.Repo.Migrations.CreateSlides do
  use Ecto.Migration

  def change do
    create table(:slides) do
      add :order, :integer
      add :mobile_img_url, :string
      add :img_url, :string
      add :remarks, :string
      add :is_show, :boolean, default: false, null: false

      timestamps()
    end

  end
end
