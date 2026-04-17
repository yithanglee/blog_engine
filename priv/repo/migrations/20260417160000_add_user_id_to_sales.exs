defmodule BlogEngine.Repo.Migrations.AddUserIdToSales do
  use Ecto.Migration

  def change do
    alter table(:sales) do
      add :user_id, references(:users)
    end

    create index(:sales, [:user_id])
  end
end

