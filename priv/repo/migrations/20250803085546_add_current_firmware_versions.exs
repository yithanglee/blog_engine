defmodule BlogEngine.Repo.Migrations.AddCurrentFirmwareVersions do
  use Ecto.Migration

  def change do
    alter table("devices") do
      add :current_firmware_version, :string, default: "1.0.0"
    end
  end
end
