defmodule BlogEngine.Repo.Migrations.AddPointsAndCreateUserPointTransactions do
  use Ecto.Migration

  def change do
    alter table(:user_topups) do
      add :points_balance, :float, default: 0.0
    end

    alter table(:organizations) do
      add :points_per_rm, :float, default: 1.0
      add :point_collection_enabled, :boolean, default: true
    end

    alter table(:vouchers) do
      add :points_required, :float, default: 0.0
      add :is_point_voucher, :boolean, default: false
    end

    create table(:user_point_transactions) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :organization_id, references(:organizations, on_delete: :delete_all)
      add :points, :float, null: false, default: 0.0
      add :before_points, :float, default: 0.0
      add :after_points, :float, default: 0.0
      add :transaction_type, :string, default: "earned"
      add :remarks, :string
      add :user_topup_transaction_id, references(:user_topup_transactions, on_delete: :nilify_all)
      add :voucher_id, references(:vouchers, on_delete: :nilify_all)

      timestamps()
    end

    create index(:user_point_transactions, [:user_id, :organization_id])
    create index(:user_point_transactions, [:organization_id])
    create index(:user_point_transactions, [:transaction_type])
  end
end
