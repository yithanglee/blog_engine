defmodule BlogEngine.Settings.Section do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sections" do
    field(:class_list, :string)
    field(:content1, :binary)
    field(:content1_class_list, :string)
    field(:content2, :binary)
    field(:content2_class_list, :string)
    field(:content3, :binary)
    field(:content3_class_list, :string)
    field(:content4, :binary)
    field(:content4_class_list, :string)
    field(:name, :string)

    field(:plain_content1, :string)
    field(:plain_content2, :string)
    field(:plain_content3, :string)
    field(:plain_content4, :string)
    timestamps()
  end

  @doc false
  def changeset(section, attrs) do
    section
    |> cast(attrs, [
      :plain_content1,
      :plain_content2,
      :plain_content3,
      :plain_content4,
      :content1,
      :content1_class_list,
      :content2,
      :content2_class_list,
      :content3,
      :content3_class_list,
      :content4,
      :content4_class_list,
      :name,
      :class_list
    ])

    # |> validate_required([:content1, :content1_class_list, :content2, :content2_class_list, :content3, :content3_class_list, :content4, :content4_class_list, :name, :class_list])
  end
end
