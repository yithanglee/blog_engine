defmodule BlogEngine.Settings.Slide do
  use Ecto.Schema
  import Ecto.Changeset

  schema "slides" do
    field(:mobile_img_url, :string)
    field(:img_url, :string)
    field(:is_show, :boolean, default: false)
    field(:order, :integer)
    field(:remarks, :string)
    field(:class_list, :string, default: "col-lg-4 col-sm-6 col-12")
    field(:content, :binary)
    field(:is_banner, :boolean, default: false)
    timestamps()
  end

  @doc false
  def changeset(slide, attrs) do
    slide
    |> cast(attrs, [
      :class_list,
      :content,
      :is_banner,
      :mobile_img_url,
      :order,
      :img_url,
      :remarks,
      :is_show
    ])

    # |> validate_required([:order, :img_url, :remarks, :is_show])
  end
end
