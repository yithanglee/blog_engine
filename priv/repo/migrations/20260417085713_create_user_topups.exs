defmodule BlogEngine.Repo.Migrations.CreateUserTopups do
  use Ecto.Migration

  def change do
    create table(:user_topups) do
      add :user_id, references(:users)
      add :balance, :float
      add :organization_id, references(:organizations)

      timestamps()
    end

  end
end
