defmodule BlogEngine.Repo.Migrations.AddSalesIdToSi do
  use Ecto.Migration

  def change do
    alter table("sales_items" ) do 
      add :sales_id, references(:sales)
      add :item_id, references(:items)
    end 
  end
end
