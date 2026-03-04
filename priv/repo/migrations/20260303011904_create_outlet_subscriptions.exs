defmodule BlogEngine.Repo.Migrations.CreateOutletSubscriptions do
  use Ecto.Migration

  def change do
    create table(:outlet_subscriptions) do
      add :outlet_id, references(:devices)
      add :amount, :float
      add :start_date, :date
      add :end_date, :date
      add :ref_no, :string
      add :payment_url, :string
      add :webhook_details, :string

      timestamps()
    end

  end
end
