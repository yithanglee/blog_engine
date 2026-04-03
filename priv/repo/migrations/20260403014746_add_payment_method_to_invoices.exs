defmodule BlogEngine.Repo.Migrations.AddPaymentMethodToInvoices do
  use Ecto.Migration

  def change do

    alter table("invoices") do
      add :payment_method, :string, default: "fpx"
    end
  end
end
