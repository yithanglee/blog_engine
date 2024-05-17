defmodule BlogEngine.Repo.Migrations.AddDefaultIoPin do
  use Ecto.Migration

  def change do
    alter table("devices") do
      add :default_io_pin, :integer, default: 0
    end
  end
end
