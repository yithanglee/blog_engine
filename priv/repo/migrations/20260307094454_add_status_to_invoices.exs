defmodule BlogEngine.Repo.Migrations.AddStatusToInvoices do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add :status, :string, default: "pending"
    end
  end
end
