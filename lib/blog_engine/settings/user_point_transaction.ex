defmodule BlogEngine.Settings.UserPointTransaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_point_transactions" do
    field :points, :float, default: 0.0
    field :before_points, :float, default: 0.0
    field :after_points, :float, default: 0.0
    field :transaction_type, :string, default: "earned"
    field :remarks, :string

    belongs_to :user, BlogEngine.Settings.User
    belongs_to :organization, BlogEngine.Settings.Organization
    belongs_to :user_topup_transaction, BlogEngine.Settings.UserTopupTransaction
    belongs_to :voucher, BlogEngine.Settings.Voucher

    timestamps()
  end

  @doc false
  def changeset(user_point_transaction, attrs) do
    user_point_transaction
    |> cast(attrs, [
      :user_id,
      :organization_id,
      :points,
      :before_points,
      :after_points,
      :transaction_type,
      :remarks,
      :user_topup_transaction_id,
      :voucher_id
    ])
    |> validate_required([
      :user_id,
      :organization_id,
      :points,
      :before_points,
      :after_points,
      :transaction_type
    ])
  end
end
