defmodule BlogEngine.Settings.UserVoucher do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_vouchers" do
    field :status, :string, default: "issued"
    field :redeemed_at, :naive_datetime
    field :expires_at, :naive_datetime

    belongs_to :user, BlogEngine.Settings.User
    belongs_to :voucher, BlogEngine.Settings.Voucher
    belongs_to :organization, BlogEngine.Settings.Organization

    timestamps()
  end

  @doc false
  def changeset(user_voucher, attrs) do
    user_voucher
    |> cast(attrs, [
      :user_id,
      :voucher_id,
      :organization_id,
      :status,
      :redeemed_at,
      :expires_at
    ])
    |> validate_required([:user_id, :voucher_id, :organization_id])
  end
end
