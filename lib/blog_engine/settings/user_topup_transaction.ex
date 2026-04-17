defmodule BlogEngine.Settings.UserTopupTransaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_topup_transactions" do
    field :after_amt, :float
    field :amount, :float
    field :before_amt, :float
    belongs_to :device_log, BlogEngine.Settings.DeviceLog
    field :remarks, :string
    belongs_to :sales, BlogEngine.Settings.Sale
    belongs_to :user, BlogEngine.Settings.User
    belongs_to :user_topup, BlogEngine.Settings.UserTopup

    timestamps()
  end

  @doc false
  def changeset(user_topup_transaction, attrs) do
    user_topup_transaction
    |> cast(attrs, [:user_topup_id, :before_amt, :after_amt, :amount, :remarks, :user_id, :sales_id, :device_log_id])
    |> validate_required([:user_topup_id, :before_amt, :after_amt, :amount, :remarks, :user_id])
  end
end
