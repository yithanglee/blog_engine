defmodule BlogEngine.Repo.Migrations.CreateSales do
  use Ecto.Migration

  def change do
    create table(:sales) do
      add :outlet_id, :integer
      add :amount, :float
      add :status, :string
      add :payment_ref, :string
      add :payment_channel, :string
      add :payment_webhook, :binary
      add :sales_date, :date

      timestamps()
    end

  end
end
