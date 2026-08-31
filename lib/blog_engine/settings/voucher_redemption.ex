defmodule BlogEngine.Settings.VoucherRedemption do
  use Ecto.Schema
  import Ecto.Changeset

  schema "voucher_redemptions" do
    field :amount, :float, default: 0.0
    field :redeemed_at, :naive_datetime

    belongs_to :voucher, BlogEngine.Settings.Voucher
    belongs_to :user, BlogEngine.Settings.User
    belongs_to :organization, BlogEngine.Settings.Organization

    timestamps()
  end

  @doc false
  def changeset(voucher_redemption, attrs) do
    voucher_redemption
    |> cast(attrs, [
      :voucher_id,
      :user_id,
      :organization_id,
      :amount,
      :redeemed_at
    ])
    |> validate_required([:voucher_id, :user_id, :organization_id, :amount])
    |> unique_constraint([:voucher_id, :user_id], name: :voucher_redemptions_voucher_id_user_id_index)
  end
end
