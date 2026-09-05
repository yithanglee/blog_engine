defmodule BlogEngine.Repo.Migrations.RenameFirebaseAuthIdToGoogleSub do
  use Ecto.Migration

  def up do
    drop_if_exists index(:users, [:firebase_auth_id], name: :users_firebase_auth_id_unique)

    rename table(:users), :firebase_auth_id, to: :google_sub

    create unique_index(:users, [:google_sub],
             where: "google_sub IS NOT NULL",
             name: :users_google_sub_unique
           )
  end

  def down do
    drop_if_exists index(:users, [:google_sub], name: :users_google_sub_unique)

    rename table(:users), :google_sub, to: :firebase_auth_id

    create unique_index(:users, [:firebase_auth_id],
             where: "firebase_auth_id IS NOT NULL",
             name: :users_firebase_auth_id_unique
           )
  end
end
