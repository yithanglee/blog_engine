defmodule BlogEngine.Repo.Migrations.AddInvoiceIdToOutletSubscriptions do
  use Ecto.Migration

  def change do
    alter table("outlet_subscriptions") do
      add :invoice_id, references(:invoices)
    end
  end
end
