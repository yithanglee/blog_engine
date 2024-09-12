defmodule BlogEngine.Settings.Brand do
  use Ecto.Schema
  import Ecto.Changeset

  schema "brands" do
    field(:desc, :binary)
    field(:img_url, :string)
    field(:name, :string)
    field(:short_desc, :binary)

    timestamps()
  end

  @doc false
  def changeset(brand, attrs) do
    brand
    |> cast(attrs, [:name, :desc, :short_desc, :img_url])

    # |> validate_required([:name, :desc, :short_desc, :img_url])
  end
end
