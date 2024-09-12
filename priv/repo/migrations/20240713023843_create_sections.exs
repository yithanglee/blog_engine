defmodule BlogEngine.Repo.Migrations.CreateSections do
  use Ecto.Migration

  def change do
    create table(:sections) do
      add :content1, :binary
      add :content1_class_list, :string
      add :content2, :binary
      add :content2_class_list, :string
      add :content3, :binary
      add :content3_class_list, :string
      add :content4, :binary
      add :content4_class_list, :string
      add :name, :string
      add :class_list, :string

      timestamps()
    end

  end
end
