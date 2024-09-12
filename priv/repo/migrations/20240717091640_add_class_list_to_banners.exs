defmodule BlogEngine.Repo.Migrations.AddClassListToBanners do
  use Ecto.Migration

  def change do
    alter table("slides") do
      add :class_list, :string, default: "col-lg-4 col-sm-6 col-12"
    end
  end
end
