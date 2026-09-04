defmodule BlogEngine.Repo.Migrations.CreateUserVouchers do
  use Ecto.Migration

  def change do
    create table(:user_vouchers) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :voucher_id, references(:vouchers, on_delete: :delete_all), null: false
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :status, :string, default: "issued", null: false
      add :expires_at, :naive_datetime
      add :redeemed_at, :naive_datetime

      timestamps()
    end

    create index(:user_vouchers, [:user_id])
    create index(:user_vouchers, [:voucher_id])
    create index(:user_vouchers, [:organization_id])
    create index(:user_vouchers, [:status])
    create index(:user_vouchers, [:user_id, :status])
  end
end
