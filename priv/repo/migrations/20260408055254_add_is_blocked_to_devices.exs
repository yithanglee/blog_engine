defmodule BlogEngine.Repo.Migrations.AddIsBlockedToDevices do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :is_blocked, :boolean, default: false
    end
  end
end
