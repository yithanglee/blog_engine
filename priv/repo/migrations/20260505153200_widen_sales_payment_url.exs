defmodule BlogEngine.Repo.Migrations.WidenSalesPaymentUrl do
  use Ecto.Migration

  def change do
    alter table(:sales) do
      modify :payment_url, :text
    end
  end
end

