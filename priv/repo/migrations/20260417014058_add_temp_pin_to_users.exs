defmodule BlogEngine.Repo.Migrations.AddTempPinToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :temp_pin, :string
    end
  end
end
