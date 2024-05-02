defmodule BlogEngine.Settings.Device do
  use Ecto.Schema
  import Ecto.Changeset

  schema "devices" do
    field(:is_active, :boolean, default: false)
    field(:is_suspended, :boolean, default: false)
    field(:name, :string)
    field(:short_desc, :string)

    timestamps()
  end

  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [:name, :short_desc, :is_active, :is_suspended])

    # |> validate_required([:name, :short_desc, :is_active, :is_suspended])
  end
end
