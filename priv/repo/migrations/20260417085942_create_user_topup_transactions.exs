defmodule BlogEngine.Repo.Migrations.CreateUserTopupTransactions do
  use Ecto.Migration

  def change do
    create table(:user_topup_transactions) do
      add :user_topup_id, references(:user_topups)
      add :before_amt, :float
      add :after_amt, :float
      add :amount, :float
      add :remarks, :string
      add :user_id, references(:users)
      add :sales_id, references(:sales)
      add :device_log_id, references(:device_logs)

      timestamps()
    end

  end
end
