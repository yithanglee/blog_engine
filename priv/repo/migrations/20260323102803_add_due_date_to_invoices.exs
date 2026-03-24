defmodule BlogEngine.Repo.Migrations.AddDueDateToInvoices do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add :due_date, :date
    end
  end
end
