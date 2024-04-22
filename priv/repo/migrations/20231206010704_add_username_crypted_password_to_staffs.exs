defmodule BlogEngine.Repo.Migrations.AddUsernameCryptedPasswordToStaffs do
  use Ecto.Migration

  def change do
    alter table("staffs") do
      add :username, :string 
      add :crypted_password, :string 
    end
  end
end
