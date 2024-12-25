defmodule BlogEngine.Settings.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "items" do
    field(:desc, :binary)
    field(:image_url, :string)
    field(:name, :string)
    field(:price, :float)

    belongs_to(:organization, BlogEngine.Settings.Organization)
    field(:short_name1, :string)
    field(:short_name2, :string)
    belongs_to(:outlet, BlogEngine.Settings.Outlet)
    field(:reps, :integer, default: 1)
    field(:delay, :float, default: 0.0)
    timestamps()
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :organization_id,
      :short_name1,
      :short_name2,
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
