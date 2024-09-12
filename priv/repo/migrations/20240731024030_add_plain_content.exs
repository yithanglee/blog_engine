defmodule BlogEngine.Repo.Migrations.AddPlainContent do
  use Ecto.Migration

  def change do
    alter table("sections") do
      add :plain_content1, :string
      add :plain_content2, :string
      add :plain_content3, :string
      add :plain_content4, :string
    end
  end
end
