defmodule BlogEngine.Repo.Migrations.AddPaymentUrl do
  use Ecto.Migration

  def change do
    alter table("sales") do
       add :payment_url, :string 
    end
  end
end
