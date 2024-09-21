defmodule BlogEngine.Settings.Page do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pages" do
    field(:content, :binary)
    field(:file_name, :string)
    field(:img_url, :string)
    field(:name, :string)
    field(:route_name, :string)

    field(:show_nav, :boolean, default: true)
    field(:subtitle, :string)
    field(:sorting_index, :integer, default: 0)
    timestamps()
  end

  @doc false
  def changeset(page, attrs) do
    page
    |> cast(attrs, [
      :show_nav,
      :sorting_index,
      :name,
      :subtitle,
      :content,
      :img_url,
      :route_name,
      :file_name
    ])

    # |> validate_required([:name, :subtitle, :content, :img_url, :route_name, :file_name])
  end
end
