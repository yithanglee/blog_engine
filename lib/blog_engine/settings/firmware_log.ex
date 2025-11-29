defmodule BlogEngine.Settings.FirmwareLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "firmware_logs" do
    field :action, :string
    # field :device_id, :integer
    belongs_to :device, BlogEngine.Settings.Device
    field :version, :string

    timestamps()
  end

  @doc false
  def changeset(firmware_log, attrs) do
    firmware_log
    |> cast(attrs, [:device_id, :action, :version])
    |> validate_required([:device_id, :action, :version])
  end
end
