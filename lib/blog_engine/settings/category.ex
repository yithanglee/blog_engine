defmodule BlogEngine.Settings.Category do
  use Ecto.Schema
  import Ecto.Changeset

  schema "categories" do
    field(:desc, :string)
    field(:name, :string)
    field(:parent_id, :integer)

    timestamps()
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :desc, :parent_id])

    # |> validate_required([:name, :desc, :parent_id])
  end
end
