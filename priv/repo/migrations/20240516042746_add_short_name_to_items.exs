defmodule BlogEngine.Repo.Migrations.AddShortNameToItems do
  use Ecto.Migration

  def change do
alter table("items") do
  add :short_name1, :string
  add :short_name2, :string
end
  end
end
