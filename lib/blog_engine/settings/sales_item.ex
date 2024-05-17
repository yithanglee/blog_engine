defmodule BlogEngine.Settings.SalesItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sales_items" do
    field(:item_amount, :float, default: 0.0)
    field(:item_name, :string)
    field(:qty, :integer)
    field(:subtotal, :float, default: 0.0)
    belongs_to(:sales, BlogEngine.Settings.Sale)
    belongs_to(:item, BlogEngine.Settings.Item)
    timestamps()
  end

  @doc false
  def changeset(sales_item, attrs) do
    sales_item
    |> cast(attrs, [:item_name, :item_amount, :item_id, :qty, :subtotal, :sales_id])
    |> validate_required([:item_name, :item_amount, :qty, :subtotal])
  end
end
