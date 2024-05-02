defmodule BlogEngine.Repo.Migrations.CreateSalesItems do
  use Ecto.Migration

  def change do
    create table(:sales_items) do
      add :item_name, :string
      add :item_amount, :float, default: 0.0
      add :qty, :integer
      add :subtotal, :float, default: 0.0

      timestamps()
    end

  end
end
