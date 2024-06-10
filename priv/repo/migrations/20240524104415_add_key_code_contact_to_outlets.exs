defmodule BlogEngine.Repo.Migrations.AddKeyCodeContactToOutlets do
  use Ecto.Migration

  def change do
    alter table("outlets") do
       add :mkey, :string
       add :mcode, :string
       add :phone, :string
       add :email, :string 
       add :collection_id, :string 
       add :payment_gateway, :string 
    end
  end
end
