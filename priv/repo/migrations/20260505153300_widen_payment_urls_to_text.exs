defmodule BlogEngine.Repo.Migrations.WidenPaymentUrlsToText do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      modify :payment_url, :text
    end

    alter table(:outlet_subscriptions) do
      modify :payment_url, :text
    end
  end
end

