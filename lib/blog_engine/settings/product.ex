defmodule BlogEngine.Settings.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field(:balance, :integer)
    belongs_to(:brand, BlogEngine.Settings.Brand)
    belongs_to(:category, BlogEngine.Settings.Category)
    # field(:brand_id, :integer)
    # field(:category_id, :integer)
    field(:desc, :binary)
    field(:img_url, :string)
    field(:img_url2, :string)
    field(:img_url3, :string)
    field(:img_url4, :string)
    field(:img_url5, :string)
    field(:img_url6, :string)
    field(:name, :string)
    field(:short_desc, :binary)

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [
      :name,
      :short_desc,
      :desc,
      :category_id,
      :brand_id,
      :img_url,
      :img_url2,
      :img_url3,
      :img_url4,
      :img_url5,
      :img_url6,
      :balance
    ])

    # |> validate_required([:name, :short_desc, :desc, :category_id, :brand_id, :img_url, :img_url2, :img_url3, :img_url4, :img_url5, :img_url6, :balance])
  end
end
