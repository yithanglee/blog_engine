defmodule BlogEngine.Repo.Migrations.AddMkeyMcodeToOrganizations do
  use Ecto.Migration

  def change do

      alter table(:organizations) do
        add :mkey, :string
        add :mcode, :string
      end

  end
end
