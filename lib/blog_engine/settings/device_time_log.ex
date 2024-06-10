defmodule BlogEngine.Settings.DeviceTimeLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "device_time_logs" do
    field :device_id, :integer

    timestamps()
  end

  @doc false
  def changeset(device_time_log, attrs) do
    device_time_log
    |> cast(attrs, [:device_id])
    |> validate_required([:device_id])
  end
end
