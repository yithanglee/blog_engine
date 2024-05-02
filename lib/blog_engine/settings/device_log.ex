defmodule BlogEngine.Settings.DeviceLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "device_logs" do
    field(:device_id, :integer)
    field(:remarks, :string)
    field(:uuid, :string)

    timestamps()
  end

  @doc false
  def changeset(device_log, attrs) do
    device_log
    |> cast(attrs, [:device_id, :uuid, :remarks])

    # |> validate_required([:device_id, :uuid, :remarks])
  end
end
