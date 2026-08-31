defmodule BlogEngine.Repo.Migrations.CreateOrganizationRedemptionRules do
  use Ecto.Migration

  def change do
    create table(:organization_redemption_rules) do
      add :name, :string, null: false
      add :description, :string
      add :points_required, :float, default: 0.0, null: false
      add :reward_amount, :float, default: 0.0, null: false
      add :voucher_prefix, :string, default: "REW"
      add :voucher_expiry_days, :integer, default: 30
      add :is_active, :boolean, default: true, null: false
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:organization_redemption_rules, [:organization_id])
    create index(:organization_redemption_rules, [:is_active])
  end
end
