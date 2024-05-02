defmodule BlogEngine.Settings.Outlet do
  use Ecto.Schema
  import Ecto.Changeset

  schema "outlets" do
    field(:address, :string)
    field(:block_reason, :string)
    field(:is_blocked, :boolean, default: false)
    field(:name, :string)

    timestamps()
  end

  @doc false
  def changeset(outlet, attrs) do
    outlet
    |> cast(attrs, [:name, :address, :is_blocked, :block_reason])

    # |> validate_required([:name, :address, :is_blocked, :block_reason])
  end
end
