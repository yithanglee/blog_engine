defmodule BlogEngine.Settings.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  schema "organizations" do
    field(:address, :string)
    field(:service_account_url, :string)
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
    field(:mkey, :string)
    field(:mcode, :string)
    field(:tnc, :binary)
    field(:points_per_rm, :float, default: 1.0)
    field(:point_collection_enabled, :boolean, default: true)
    has_many(:outlets, BlogEngine.Settings.Outlet)

    timestamps()
  end

  @doc false
  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [
      :service_account_url,
      :tnc,
      :points_per_rm,
      :point_collection_enabled,
      :name,
      :mkey,
      :mcode,
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
