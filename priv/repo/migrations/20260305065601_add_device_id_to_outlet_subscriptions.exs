defmodule BlogEngine.Repo.Migrations.AddDeviceIdToOutletSubscriptions do
  use Ecto.Migration

  def change do
    alter table("outlet_subscriptions") do
      add :device_id, references(:devices)
    end
  end
end
