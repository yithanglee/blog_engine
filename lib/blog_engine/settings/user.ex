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
    field(:email, :string)
    field(:fullname, :string)
    field(:ic_no, :string)
    field(:phone, :string)
    # field(:rank_name, :string)
    field(:username, :string)
    # field(:firebase_auth_id, :string)
    # belongs_to(:rank, BlogEngine.Settings.Rank)
    belongs_to(:organization, BlogEngine.Settings.Organization)
    # has_one(:royalty_user, BlogEngine.Settings.RoyaltyUser)
    # field(:u2, :string, virtual: true)
    # field(:u3, :string, virtual: true)
    # has_one(:merchant, BlogEngine.Settings.Merchant)
    # field(:placement, :string, virtual: true)

    # field(:country_id, :integer)
    # field(:is_stockist, :boolean, default: false)
    # has_one(:placement, BlogEngine.Settings.Placement)
    # field(:stockist_user_id, :integer)

    # has_many(:stockist_users, BlogEngine.Settings.User, foreign_key: :stockist_user_id)
    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
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
      :bank_name
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
