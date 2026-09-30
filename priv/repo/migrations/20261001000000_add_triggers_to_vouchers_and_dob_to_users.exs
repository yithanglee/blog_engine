defmodule BlogEngine.Repo.Migrations.AddTriggersToVouchersAndDobToUsers do
  use Ecto.Migration

  def up do
    alter table(:vouchers) do
      add :trigger_type, :string, default: "regular", null: false
      add :voucher_expiry_days, :integer, default: 30
    end

    create index(:vouchers, [:trigger_type])

    alter table(:users) do
      add :dob, :date
    end

    flush()

    execute("""
    INSERT INTO vouchers (code, amount, status, max_redemptions, redemptions_count, remarks, trigger_type, voucher_expiry_days, organization_id, inserted_at, updated_at)
    SELECT 
      CONCAT('ONBOARD-', o.id),
      5.0,
      'active',
      999999,
      0,
      'Default Welcome Voucher Template',
      'onboard',
      30,
      o.id,
      NOW(),
      NOW()
    FROM organizations o
    WHERE NOT EXISTS (
      SELECT 1 FROM vouchers v WHERE v.organization_id = o.id AND v.trigger_type = 'onboard'
    );
    """)
  end

  def down do
    alter table(:users) do
      remove :dob
    end

    drop_if_exists index(:vouchers, [:trigger_type])

    alter table(:vouchers) do
      remove :trigger_type
      remove :voucher_expiry_days
    end
  end
end
