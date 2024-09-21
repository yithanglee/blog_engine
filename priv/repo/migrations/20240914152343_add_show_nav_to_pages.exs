defmodule BlogEngine.Repo.Migrations.AddShowNavToPages do
  use Ecto.Migration

  def change do
    alter table("pages") do
       add :show_nav, :boolean, default: true
    end
  end 
end
