defmodule BlogEngine.Settings.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "items" do
    field(:desc, :binary)
    field(:image_url, :string)
    field(:name, :string)
    field(:price, :float)

    timestamps()
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :price, :desc, :image_url])

    # |> validate_required([:name, :price, :desc, :image_url])
  end
end
