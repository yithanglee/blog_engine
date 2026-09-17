defmodule BlogEngine.Repo.Migrations.WidenWebhookDetailsToText do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      modify :webhook_details, :text
    end

    alter table(:outlet_subscriptions) do
      modify :webhook_details, :text
    end
  end
end
