defmodule BlogEngine.Settings.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  schema "subscriptions" do
    field :amount, :float
    field :description, :string
    field :duration_in_months, :integer
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:amount, :name, :description, :duration_in_months])
    |> validate_required([:amount, :name, :description, :duration_in_months])
  end
end
