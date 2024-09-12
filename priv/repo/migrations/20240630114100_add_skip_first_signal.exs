defmodule BlogEngine.Repo.Migrations.AddSkipFirstSignal do
  use Ecto.Migration

  def change do
    alter table("devices") do 

      add :skip_first, :boolean, default: false
    end
  end
end
