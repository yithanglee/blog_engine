defmodule BlogEngine.Repo.Migrations.AddShortNameToDevices do
  use Ecto.Migration

  def change do
alter table("devices") do
  add :short_name, :string
end
  end
end
