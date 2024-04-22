defmodule BlogEngine.Settings.StoredMedia do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stored_medias" do
    field(:blog_id, :integer)
    field(:file_type, :string)
    field(:format, :string)
    field(:name, :string)
    field(:url, :string)

    timestamps()
  end

  @doc false
  def changeset(stored_media, attrs) do
    stored_media
    |> cast(attrs, [:name, :format, :url, :file_type, :blog_id])

    # |> validate_required([:name, :format, :url, :file_type, :blog_id])
  end
end
