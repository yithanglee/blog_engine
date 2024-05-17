defmodule BlogEngine.Repo.Migrations.AddOutletIdToDevices do
  use Ecto.Migration

  def change do
    alter table("devices") do
       add :outlet_id, references(:outlets)
    end
  end
end
