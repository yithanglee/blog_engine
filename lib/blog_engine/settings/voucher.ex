defmodule BlogEngine.Settings.Voucher do
  use Ecto.Schema
  import Ecto.Changeset

  schema "vouchers" do
    field :code, :string
    field :amount, :float, default: 0.0
    field :expires_at, :naive_datetime
    field :status, :string, default: "active"
    field :points_required, :float, default: 0.0
    field :is_point_voucher, :boolean, default: false
    field :max_redemptions, :integer, default: 1
    field :redemptions_count, :integer, default: 0
    field :batch_no, :string
    field :remarks, :string
    field :image_url, :string
    field :redeemed_at, :naive_datetime

    belongs_to :organization, BlogEngine.Settings.Organization
    belongs_to :redeemed_by_user, BlogEngine.Settings.User, foreign_key: :redeemed_by_user_id
    has_many :voucher_redemptions, BlogEngine.Settings.VoucherRedemption, on_delete: :delete_all
    has_many :user_vouchers, BlogEngine.Settings.UserVoucher, on_delete: :delete_all

    timestamps()
  end

  @doc false
  def changeset(voucher, attrs) do
    voucher
    |> cast(attrs, [
      :code,
      :amount,
      :points_required,
      :is_point_voucher,
      :expires_at,
      :status,
      :max_redemptions,
      :redemptions_count,
      :batch_no,
      :remarks,
      :image_url,
      :organization_id,
      :redeemed_by_user_id,
      :redeemed_at
    ])
    |> validate_required([:code, :amount, :organization_id])
    |> unique_constraint(:code, name: :vouchers_code_organization_id_index)
  end
end
