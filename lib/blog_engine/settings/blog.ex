defmodule BlogEngine.Settings.Blog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "blogs" do
    # field(:category_id, :integer)
    belongs_to(:category, BlogEngine.Settings.Category)
    field(:content, :binary)
    field(:excerpt, :string)
    field(:img_url, :string)
    field(:thumbnail_img, :string)
    field(:title, :string)
    has_many(:stored_medias, BlogEngine.Settings.StoredMedia, on_replace: :delete)
    timestamps()
  end

  @doc false
  def changeset(blog, attrs) do
    blog = blog |> BlogEngine.Repo.preload([:stored_medias])

    blog
    |> cast(attrs, [:title, :excerpt, :thumbnail_img, :img_url, :category_id, :content])
    |> cast_assoc(:stored_medias, with: &BlogEngine.Settings.StoredMedia.changeset/2)

    # |> validate_required([:title, :excerpt, :thumbnail_img, :img_url, :category_id, :content])
  end
end
