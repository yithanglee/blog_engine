defmodule BlogEngine.Repo.Migrations.AddRatesPerMinuiteToOutlets do
  use Ecto.Migration

  def change do
alter table("outlets") do
   add :price_per_minutes, :float, default: 0.5
end
  end
end
