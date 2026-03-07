defmodule BlogEngine.Settings.Invoice do
  use Ecto.Schema
  import Ecto.Changeset

  schema "invoices" do
    field(:grand_total, :float)
    field(:organization_id, :integer)
    field(:payment_url, :string)
    field(:ref_no, :string)
    field(:remarks, :string)
    field(:staff_id, :integer)
    field(:webhook_details, :string)

    timestamps()
  end

  @doc false
  def changeset(invoice, attrs) do
    invoice
    |> cast(attrs, [
      :organization_id,
      :ref_no,
      :remarks,
      :staff_id,
      :grand_total,
      :payment_url,
      :webhook_details
    ])

    # |> validate_required([:organization_id, :ref_no, :remarks, :staff_id, :grand_total, :payment_url, :webhook_details])
  end
end
