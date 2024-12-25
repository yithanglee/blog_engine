defmodule BlogEngine.Settings.Staff do
  use Ecto.Schema
  import Ecto.Changeset

  schema "staffs" do
    field(:desc, :string)
    field(:email, :string)
    field(:name, :string)
    field(:phone, :string)
    belongs_to(:organization, BlogEngine.Settings.Organization)
    field(:password, :string, virtual: true)
    field(:username, :string)
    field(:crypted_password, :string)
    belongs_to(:role, BlogEngine.Settings.Role)
    has_many(:messaging_devices, BlogEngine.Settings.MessagingDevice)
    timestamps()
  end

  @doc false
  def changeset(staff, attrs) do
    staff
    |> cast(attrs, [
      :organization_id,
      :role_id,
      :crypted_password,
      :username,
      :name,
      :email,
      :desc,
      :phone
    ])
    |> validate_required([:name])
  end
end
