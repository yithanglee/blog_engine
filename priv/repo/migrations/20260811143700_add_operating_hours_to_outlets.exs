defmodule BlogEngine.Repo.Migrations.AddOperatingHoursToOutlets do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE outlets ADD COLUMN IF NOT EXISTS operating_hours_start TIME;")
    execute("ALTER TABLE outlets ADD COLUMN IF NOT EXISTS operating_hours_end TIME;")
  end

  def down do
    execute("ALTER TABLE outlets DROP COLUMN IF EXISTS operating_hours_start;")
    execute("ALTER TABLE outlets DROP COLUMN IF EXISTS operating_hours_end;")
  end
end
