defmodule BlogEngine.Repo.Migrations.AddEmailToOrganizations do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE organizations ADD COLUMN IF NOT EXISTS email VARCHAR(255)"
  end

  def down do
    alter table(:organizations) do
      remove :email
    end
  end
end
