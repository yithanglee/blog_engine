defmodule BlogEngine.Repo.Migrations.AddSubscriptionIdToOutletSubscriptions do
  use Ecto.Migration

  def change do
    alter table("outlet_subscriptions") do
      add :subscription_id, references(:subscriptions)
    end
  end
end
