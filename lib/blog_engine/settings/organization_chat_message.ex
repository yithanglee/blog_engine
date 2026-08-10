defmodule BlogEngine.Settings.OrganizationChatMessage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "organization_chat_messages" do
    field(:body, :string)
    field(:sender_role, :string)
    field(:sender_label, :string)

    belongs_to(:organization, BlogEngine.Settings.Organization)
    belongs_to(:user, BlogEngine.Settings.User)
    belongs_to(:staff, BlogEngine.Settings.Staff)

    timestamps()
  end

  @doc false
  def changeset(organization_chat_message, attrs) do
    organization_chat_message
    |> cast(attrs, [:organization_id, :body, :sender_role, :sender_label, :user_id, :staff_id])
    |> validate_required([:organization_id, :body, :sender_role])
  end
end
