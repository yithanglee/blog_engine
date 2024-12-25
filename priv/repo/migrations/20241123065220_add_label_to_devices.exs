defmodule BlogEngine.Repo.Migrations.AddLabelToDevices do
  use Ecto.Migration

  def change do
    alter table("devices") do
      add :label, :string     
    end
    
  end
end
