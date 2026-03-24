defmodule BlogEngine.Settings.Invoice do
  use Ecto.Schema
  import Ecto.Changeset

  schema "invoices" do
    field(:grand_total, :float)
    # field(:organization_id, :integer)
    belongs_to(:organization, BlogEngine.Settings.Organization)

    has_many(:outlet_subscriptions, BlogEngine.Settings.OutletSubscription, on_delete: :delete_all)

    has_many(:outlets, through: [:outlet_subscriptions, :outlet])
    field(:payment_url, :string)
    field(:ref_no, :string)
    field(:remarks, :string)
    field(:staff_id, :integer)
    field(:webhook_details, :string)
    field(:status, :string)
    field(:due_date, :date)

    timestamps()
  end

  @doc false
  def changeset(invoice, attrs) do
    invoice
    |> cast(attrs, [
      :status,
      :organization_id,
      :ref_no,
      :remarks,
      :staff_id,
      :grand_total,
      :payment_url,
      :webhook_details,
      :due_date
    ])

    # |> validate_required([:organization_id, :ref_no, :remarks, :staff_id, :grand_total, :payment_url, :webhook_details])
  end
end
