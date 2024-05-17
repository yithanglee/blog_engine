defmodule BlogEngine.Settings.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "items" do
    field(:desc, :binary)
    field(:image_url, :string)
    field(:name, :string)
    field(:price, :float)
    # field(:outlet_id, :integer)
    belongs_to(:outlet, BlogEngine.Settings.Outlet)
    field(:reps, :integer, default: 1)
    field(:delay, :float, default: 0.0)
    timestamps()
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :outlet_id,
      :reps,
      :delay,
      :name,
      :price,
      :desc,
      :image_url
    ])

    # |> validate_required([:name, :price, :desc, :image_url])
  end
end
