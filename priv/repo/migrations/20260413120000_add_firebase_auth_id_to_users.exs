defmodule BlogEngine.Repo.Migrations.AddFirebaseAuthIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :firebase_auth_id, :string
    end

    create unique_index(:users, [:firebase_auth_id],
             where: "firebase_auth_id IS NOT NULL",
             name: :users_firebase_auth_id_unique
           )
  end
end
