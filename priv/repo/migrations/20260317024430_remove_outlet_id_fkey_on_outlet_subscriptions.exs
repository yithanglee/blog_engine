defmodule BlogEngine.Repo.Migrations.RemoveOutletIdFkeyOnOutletSubscriptions do
  use Ecto.Migration

  def change do
    drop constraint(:outlet_subscriptions, :outlet_subscriptions_outlet_id_fkey)
  end
end
