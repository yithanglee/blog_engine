defmodule BlogEngine.Settings.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:approved, :boolean, default: false)
    field(:bank_account_holder, :string)
    field(:bank_account_no, :string)
    field(:bank_name, :string)
    field(:blocked, :boolean, default: false)
    field(:crypted_password, :string)
    field(:password, :string, virtual: true)

    field(:temp_pin, :string)
    field(:fcm_token, :string)
    field(:email, :string)
    field(:fullname, :string)
    field(:ic_no, :string)
    field(:phone, :string)
    field(:username, :string)
    field(:google_sub, :string)
    belongs_to(:organization, BlogEngine.Settings.Organization)
    has_many(:user_vouchers, BlogEngine.Settings.UserVoucher, on_delete: :delete_all)
    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :fcm_token,
      :organization_id,
      :temp_pin,
      :email,
      :username,
      :fullname,
      :phone,
      :ic_no,
      :crypted_password,
      :approved,
      :blocked,
      :bank_account_holder,
      :bank_account_no,
      :bank_name,
      :google_sub
    ])
    |> validate_required([
      # :email,
      :username
      # :fullname,
      # :phone
      # :ic_no,
      # :crypted_password,
      # :approved,
      # :blocked,
      # :rank_name,
      # :bank_account_holder,
      # :bank_account_no,
      # :bank_name
    ])
  end
end
