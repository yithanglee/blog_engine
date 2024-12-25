defmodule BlogEngine.Repo.Migrations.CreateOrganizations do
  use Ecto.Migration

  def change do
    create table(:organizations) do
      add :name, :string
      add :desc, :string
      add :address, :string
      add :img_url, :string
      add :reg_no, :string
      add :phone, :string
      add :contact_person, :string
      add :bank_holder_name, :string
      add :bank_name, :string
      add :bank_acc_no, :string

      timestamps()
    end

  end
end
