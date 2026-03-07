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
    # field(:device_id, :integer)
    belongs_to(:device, BlogEngine.Settings.Device)
    belongs_to(:invoice, BlogEngine.Settings.Invoice)
    timestamps()
    field(:subscription_id, :integer)
  end

  @doc false
  def changeset(outlet_subscription, attrs) do
    outlet_subscription
    |> cast(attrs, [
      :invoice_id,
      :device_id,
      :status,
      :outlet_id,
      :amount,
      :start_date,
      :end_date,
      :ref_no,
      :payment_url,
      :webhook_details,
      :subscription_id
    ])
    |> validate_required([
      # :outlet_id,
      :device_id,
      :amount,
      :start_date,
      :end_date
      # :ref_no
      # :payment_url,
      # :webhook_details
    ])
  end
end
