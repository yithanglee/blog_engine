defmodule BlogEngine.Repo.Migrations.CreateStaffs do
  use Ecto.Migration

  def change do
    create table(:staffs) do
      add :name, :string
      add :email, :string
      add :desc, :string
      add :phone, :string

      timestamps()
    end

  end
end
