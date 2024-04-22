defmodule BlogEngine.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string
      add :username, :string
      add :fullname, :string
      add :phone, :string
      add :ic_no, :string
      add :crypted_password, :string
      add :approved, :boolean, default: false, null: false
      add :blocked, :boolean, default: false, null: false
      add :rank_name, :string
      add :bank_account_holder, :string
      add :bank_account_no, :string
      add :bank_name, :string

      timestamps()
    end

  end
end
