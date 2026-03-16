defmodule BlogEngine.Settings.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  schema "organizations" do
    field(:address, :string)
    field(:bank_acc_no, :string)
    field(:bank_holder_name, :string)
    field(:bank_name, :string)
    field(:contact_person, :string)
    field(:desc, :string)
    field(:email, :string)
    field(:img_url, :string)
    field(:name, :string)
    field(:phone, :string)
    field(:reg_no, :string)
    has_many(:outlets, BlogEngine.Settings.Outlet)

    timestamps()
  end

  @doc false
  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [
      :name,
      :desc,
      :address,
      :email,
      :img_url,
      :reg_no,
      :phone,
      :contact_person,
      :bank_holder_name,
      :bank_name,
      :bank_acc_no
    ])
    |> validate_required([
      :name
      # :desc,
      # :address,
      # :img_url,
      # :reg_no,
      # :phone,
      # :contact_person,
      # :bank_holder_name,
      # :bank_name,
      # :bank_acc_no
    ])
  end
end
