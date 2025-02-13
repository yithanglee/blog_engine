defmodule BlogEngine.Settings.IoReading do
  use Ecto.Schema
  import Ecto.Changeset

  schema "io_readings" do
    field :device_id, :integer
    field :final_data, :string
    field :is_processed, :boolean, default: false
    field :log, :binary

    timestamps()
  end

  @doc false
  def changeset(io_reading, attrs) do
    io_reading
    |> cast(attrs, [:device_id, :log, :is_processed, :final_data])
    |> validate_required([:device_id, :log, :is_processed, :final_data])
  end
end
