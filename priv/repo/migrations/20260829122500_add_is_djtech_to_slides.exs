defmodule BlogEngine.Repo.Migrations.AddIsDjtechToSlides do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE slides ADD COLUMN IF NOT EXISTS is_djtech BOOLEAN DEFAULT false;")
  end

  def down do
    execute("ALTER TABLE slides DROP COLUMN IF EXISTS is_djtech;")
  end
end
