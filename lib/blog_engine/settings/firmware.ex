defmodule BlogEngine.Settings.Firmware do
  use Ecto.Schema
  import Ecto.Changeset

  schema "firmwares" do
    field :metadata, :binary
    field :name, :string
    field :url, :string
    field :version, :string

    timestamps()
  end

  @doc false
  def changeset(firmware, attrs) do
    firmware
    |> cast(attrs, [:name, :version, :metadata, :url])
    |> validate_required([:name, :version, :metadata, :url])
  end
end
