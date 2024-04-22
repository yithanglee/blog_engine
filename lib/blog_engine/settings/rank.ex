defmodule BlogEngine.Settings.Rank do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ranks" do
    field(:desc, :binary)
    field(:img_url, :string)
    field(:name, :string)
    field(:point_value, :integer)
    field(:register_point, :integer)
    field(:retail_price, :float)

    timestamps()
  end

  @doc false
  def changeset(rank, attrs) do
    rank
    |> cast(attrs, [:name, :retail_price, :register_point, :point_value, :img_url, :desc])
    |> validate_required([:name, :retail_price, :register_point, :point_value])
  end
end
