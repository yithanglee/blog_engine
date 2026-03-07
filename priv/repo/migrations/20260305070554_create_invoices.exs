defmodule BlogEngine.Repo.Migrations.CreateInvoices do
  use Ecto.Migration

  def change do
    create table(:invoices) do
      add :organization_id, :integer
      add :ref_no, :string
      add :remarks, :string
      add :staff_id, :integer
      add :grand_total, :float
      add :payment_url, :string
      add :webhook_details, :string

      timestamps()
    end

  end
end
