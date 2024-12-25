defmodule BlogEngine.Repo.Migrations.AddCurrencyToOutlets do
  use Ecto.Migration

  def change do
    alter table("outlets") do
       add :currency, :string, default: "MYR"
    end
  end
end
