defmodule BlogEngine.Repo.Migrations.AddSubdomainToOutlets do
  use Ecto.Migration

  def change do
    alter table("outlets") do
      add :subdomain, :string
    end
  end
end
