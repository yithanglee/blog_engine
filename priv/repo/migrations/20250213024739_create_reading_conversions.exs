defmodule BlogEngine.Repo.Migrations.CreateReadingConversions do
  use Ecto.Migration

  def change do
    create table(:reading_conversions) do
      add :reading_start, :integer
      add :reading_end, :integer
      add :converted_data, :float

      timestamps()
    end

  end
end
