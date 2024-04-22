defmodule BlogEngine.Settings.Announcement do
  use Ecto.Schema
  import Ecto.Changeset

  schema "announcements" do
    field(:author, :string)
    field(:category, :string)
    field(:ccontent, :binary)
    field(:content, :binary)
    field(:csubtitle, :string)
    field(:ctitle, :string)
    field(:img_url, :string)
    field(:subtitle, :string)
    field(:title, :string)

    timestamps()
  end

  @doc false
  def changeset(announcement, attrs) do
    announcement
    |> cast(attrs, [
      :content,
      :title,
      :ctitle,
      :subtitle,
      :csubtitle,
      :ccontent,
      :category,
      :author,
      :img_url
    ])

    # |> validate_required([
    #   :content,
    #   :title,
    #   :ctitle,
    #   :subtitle,
    #   :csubtitle,
    #   :ccontent,
    #   :category,
    #   :author,
    #   :img_url
    # ])
  end
end
