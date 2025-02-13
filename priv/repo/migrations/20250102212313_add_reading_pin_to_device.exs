defmodule BlogEngine.Repo.Migrations.AddReadingPinToDevice do
  use Ecto.Migration

  def change do
    alter table("devices") do
      add :reading_pin, :integer, default: 16
    end
  end
end
