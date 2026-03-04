defmodule BlogEngine.Settings.OutletSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  schema "outlet_subscriptions" do
    field(:amount, :float)
    field(:end_date, :date)
    # field :outlet_id, :integer
    belongs_to(:outlet, BlogEngine.Settings.Outlet)
    field(:payment_url, :string)
    field(:ref_no, :string)
    field(:start_date, :date)
    field(:webhook_details, :string)
    field(:status, :string, default: "pending")
    timestamps()
  end

  @doc false
  def changeset(outlet_subscription, attrs) do
    outlet_subscription
    |> cast(attrs, [
      :status,
      :outlet_id,
      :amount,
      :start_date,
      :end_date,
      :ref_no,
      :payment_url,
      :webhook_details
    ])
    |> validate_required([
      :outlet_id,
      :amount,
      :start_date,
      :end_date,
      :ref_no
      # :payment_url,
      # :webhook_details
    ])
  end
end
