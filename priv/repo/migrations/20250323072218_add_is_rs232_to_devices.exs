defmodule BlogEngine.Repo.Migrations.AddIsRs232ToDevices do
  use Ecto.Migration

  def change do
alter table("devices") do
  add :is_rs232, :boolean, default: false
end
  end
end
