defmodule BlogEngine.Repo.Migrations.AddStatusToOutletSubscriptions do
  use Ecto.Migration

  def change do
    alter table("outlet_subscriptions") do
      add :status, :string, default: "pending"
    end

  end
end
