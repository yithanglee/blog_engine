defmodule BlogEngine.Repo.Migrations.AddSalesType do
  use Ecto.Migration

  def change do
    alter table("sales") do
      add :sales_type, :string, default: "offline"
    end
  end
end
