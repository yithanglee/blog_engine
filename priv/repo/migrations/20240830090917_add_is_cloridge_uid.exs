defmodule BlogEngine.Repo.Migrations.AddIsCloridgeUid do
  use Ecto.Migration

  def change do
    alter table("devices") do
      add :is_cloridge, :boolean, default: false 
      add :cloridge_device_uid, :string 
    end
  end
end
