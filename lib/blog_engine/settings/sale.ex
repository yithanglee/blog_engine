defmodule BlogEngine.Settings.Sale do
  use Ecto.Schema
  import Ecto.Changeset
  import EctoEnum

  defenum(
    StatusEnum,
    ~w(
      processing
      pending_confirmation
      preparing
      pending_delivery
      already_pickup
      pending_payment
      paid
      complete
      sent
      refund
      cancelled
    )
  )

  schema "sales" do
    field(:uid, :string)
    field(:amount, :float)
    belongs_to(:outlet, BlogEngine.Settings.Outlet)
    # field(:outlet_id, :integer)
    # field(:device_id, :integer)
    belongs_to(:device, BlogEngine.Settings.Device)

    has_many(:sales_items, BlogEngine.Settings.SalesItem, foreign_key: :sales_id)

    field(:payment_url, :string)
    field(:payment_channel, :string)
    field(:payment_ref, :string)
    field(:payment_webhook, :binary)
    field(:sales_date, :date)
    field(:status, StatusEnum, default: :pending_confirmation)

    timestamps()
  end

  @doc false
  def changeset(sale, attrs) do
    sale
    |> cast(attrs, [
      :payment_url,
      :uid,
      :outlet_id,
      :device_id,
      :amount,
      :status,
      :payment_ref,
      :payment_channel,
      :payment_webhook,
      :sales_date
    ])

    # |> validate_required([
    #   :outlet_id,
    #   :amount,
    #   :status,
    #   :payment_ref,
    #   :payment_channel,
    #   :payment_webhook,
    #   :sales_date
    # ])
  end
end
