defmodule BlogEngine.Settings.ReadingConversion do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reading_conversions" do
    field :converted_data, :float
    field :reading_end, :integer
    field :reading_start, :integer

    timestamps()
  end

  @doc false
  def changeset(reading_conversion, attrs) do
    reading_conversion
    |> cast(attrs, [:reading_start, :reading_end, :converted_data])
    |> validate_required([:reading_start, :reading_end, :converted_data])
  end
end
