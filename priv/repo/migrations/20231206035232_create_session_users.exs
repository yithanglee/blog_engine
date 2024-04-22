defmodule BlogEngine.Repo.Migrations.CreateSessionUsers do
  use Ecto.Migration

  def change do
    create table(:session_users) do
      add :cookie, :string
      add :user_id, :integer

      timestamps()
    end

  end
end
