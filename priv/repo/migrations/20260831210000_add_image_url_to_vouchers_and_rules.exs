defmodule BlogEngine.Repo.Migrations.AddImageUrlToVouchersAndRules do
  use Ecto.Migration

  def change do
    alter table(:vouchers) do
      add :image_url, :string
    end

    alter table(:organization_redemption_rules) do
      add :image_url, :string
    end
  end
end
