defmodule BlogEngine.Settings.SessionUser do
  use Ecto.Schema
  import Ecto.Changeset

  schema "session_users" do
    field(:cookie, :string)
    # field :user_id, :integer
    belongs_to(:user, BlogEngine.Settings.Staff)
    timestamps()
  end

  @doc false
  def changeset(session_user, attrs) do
    session_user
    |> cast(attrs, [:cookie, :user_id])
    |> validate_required([:cookie, :user_id])
  end
end
