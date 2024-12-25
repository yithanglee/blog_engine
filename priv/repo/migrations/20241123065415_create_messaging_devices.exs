defmodule BlogEngine.Repo.Migrations.CreateMessagingDevices do
  use Ecto.Migration

  def change do
    create table(:messaging_devices) do
      add :uuid, :string
      add :staff_id, :integer

      timestamps()
    end

  end
end
