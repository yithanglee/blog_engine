defmodule BlogEngine.Repo.Migrations.AddLatLngToOutlets do
  use Ecto.Migration

  def change do
    alter table(:outlets) do
      add :lat, :float, default: 3.139003
      add :lng, :float, default: 101.686855
    end
  end
end
