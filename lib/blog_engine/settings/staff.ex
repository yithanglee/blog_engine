defmodule BlogEngine.Settings.Staff do
  use Ecto.Schema
  import Ecto.Changeset

  schema "staffs" do
    field(:desc, :string)
    field(:email, :string)
    field(:name, :string)
    field(:phone, :string)

    field(:password, :string, virtual: true)
    field(:username, :string)
    field(:crypted_password, :string)
    belongs_to(:role, BlogEngine.Settings.Role)
    timestamps()
  end

  @doc false
  def changeset(staff, attrs) do
    staff
    |> cast(attrs, [:role_id, :crypted_password, :username, :name, :email, :desc, :phone])
    |> validate_required([:name])
  end
end
