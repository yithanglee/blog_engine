defmodule BlogEngine.Settings.Device do
  use Ecto.Schema
  import Ecto.Changeset

  schema "devices" do
    field(:is_active, :boolean, default: false)
    field(:is_suspended, :boolean, default: false)
    field(:name, :string)
    field(:short_desc, :string)
    belongs_to(:outlet, BlogEngine.Settings.Outlet)
    field(:default_io_pin, :integer, default: 0)
    timestamps()
  end

  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [:outlet_id, :default_io_pin, :name, :short_desc, :is_active, :is_suspended])

    # |> validate_required([:name, :short_desc, :is_active, :is_suspended])
  end
end
