defmodule BlogEngine.Repo.Migrations.AddSortingIndexToPages do
  use Ecto.Migration

  def change do
    alter table("pages") do
      add :sorting_index, :integer, default: 0  
    end
  end
end
