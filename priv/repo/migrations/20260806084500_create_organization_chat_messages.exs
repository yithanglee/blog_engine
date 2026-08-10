defmodule BlogEngine.Repo.Migrations.CreateOrganizationChatMessages do
  use Ecto.Migration

  def change do
    create table(:organization_chat_messages) do
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :body, :text, null: false
      add :sender_role, :string, null: false
      add :sender_label, :string
      add :user_id, references(:users, on_delete: :nilify_all)
      add :staff_id, references(:staffs, on_delete: :nilify_all)

      timestamps()
    end

    create index(:organization_chat_messages, [:organization_id])
    create index(:organization_chat_messages, [:inserted_at])
  end
end
