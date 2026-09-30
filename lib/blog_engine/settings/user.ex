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
    field(:dob, :date)
    field(:dob_update_count, :integer, default: 0)
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
      :google_sub,
      :dob,
      :dob_update_count
    ])
    |> validate_dob_update(user)
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

  defp validate_dob_update(changeset, user) do
    if Map.has_key?(changeset.changes, :dob) do
      new_dob = get_field(changeset, :dob)
      old_dob = user.dob

      if old_dob != new_dob do
        current_count = user.dob_update_count || 0

        if current_count >= 3 do
          add_error(changeset, :dob, "Date of birth can only be updated up to 3 times")
        else
          # Only auto-increment if not explicitly provided in changes
          if not Map.has_key?(changeset.changes, :dob_update_count) do
            put_change(changeset, :dob_update_count, current_count + 1)
          else
            changeset
          end
        end
      else
        changeset
      end
    else
      changeset
    end
  end
end
