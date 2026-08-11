defmodule BlogEngine.Repo.Migrations.AddOperatingHoursToOutlets do
  use Ecto.Migration

  def change do
    alter table(:outlets) do
      add :operating_hours_start, :time
      add :operating_hours_end, :time
    end
  end
end
