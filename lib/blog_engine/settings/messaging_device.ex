defmodule BlogEngine.Settings.MessagingDevice do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messaging_devices" do
    # field :user_id, :integer
    belongs_to(:staff, BlogEngine.Settings.Staff)
    field(:uuid, :string)

    timestamps()
  end

  @doc false
  def changeset(messaging_device, attrs) do
    messaging_device
    |> cast(attrs, [:uuid, :staff_id])
    |> validate_required([:uuid, :staff_id])
  end
end
