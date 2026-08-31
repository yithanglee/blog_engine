defmodule BlogEngine.Repo.Migrations.CreateVouchersAndRedemptions do
  use Ecto.Migration

  def change do
    create table(:vouchers) do
      add :code, :string, null: false
      add :amount, :float, null: false, default: 0.0
      add :expires_at, :naive_datetime
      add :status, :string, default: "active"
      add :max_redemptions, :integer, default: 1
      add :redemptions_count, :integer, default: 0
      add :batch_no, :string
      add :remarks, :string
      add :organization_id, references(:organizations, on_delete: :delete_all)
      add :redeemed_by_user_id, references(:users, on_delete: :nilify_all)
      add :redeemed_at, :naive_datetime

      timestamps()
    end

    create index(:vouchers, [:organization_id])
    create unique_index(:vouchers, [:code, :organization_id])
    create index(:vouchers, [:status])

    create table(:voucher_redemptions) do
      add :voucher_id, references(:vouchers, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)
      add :organization_id, references(:organizations, on_delete: :delete_all)
      add :amount, :float, null: false, default: 0.0
      add :redeemed_at, :naive_datetime

      timestamps()
    end

    create index(:voucher_redemptions, [:voucher_id])
    create index(:voucher_redemptions, [:user_id])
    create index(:voucher_redemptions, [:organization_id])
    create unique_index(:voucher_redemptions, [:voucher_id, :user_id])
  end
end
