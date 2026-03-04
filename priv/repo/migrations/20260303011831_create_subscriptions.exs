defmodule BlogEngine.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions) do
      add :amount, :float
      add :name, :string
      add :description, :string
      add :duration_in_months, :integer

      timestamps()
    end

  end
end
