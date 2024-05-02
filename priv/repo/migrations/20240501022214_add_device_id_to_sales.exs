defmodule BlogEngine.Repo.Migrations.AddDeviceIdToSales do
  use Ecto.Migration

  def change do
    alter table("sales") do
      add :device_id, :integer
    end
  end
end
