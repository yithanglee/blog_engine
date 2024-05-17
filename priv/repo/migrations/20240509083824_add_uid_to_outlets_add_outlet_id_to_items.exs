defmodule BlogEngine.Repo.Migrations.AddUidToOutletsAddOutletIdToItems do
  use Ecto.Migration

  def change do
    alter table("sales") do
      add :uid, :string  
    end
    
    create index(:sales, [:uid], unique: true)
    create index(:devices, [:name], unique: true)
    
    alter table("outlets") do
      add :uid, :string  
    end

    alter table("items") do
      add :outlet_id, :integer
      add :reps, :integer , default: 1
      add :delay, :float, default: 0.0 
    end
  end
end
