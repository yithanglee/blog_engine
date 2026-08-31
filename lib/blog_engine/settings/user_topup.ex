defmodule BlogEngine.Settings.UserTopup do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_topups" do
    field :balance, :float, default: 0.0
    field :points_balance, :float, default: 0.0
    belongs_to :organization, BlogEngine.Settings.Organization
    belongs_to :user, BlogEngine.Settings.User

    timestamps()
  end

  @doc false
  def changeset(user_topup, attrs) do
    user_topup
    |> cast(attrs, [:user_id, :balance, :organization_id, :points_balance])
    |> validate_required([:user_id, :balance, :organization_id])
  end
end
