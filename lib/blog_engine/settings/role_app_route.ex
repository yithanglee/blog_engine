defmodule BlogEngine.Settings.RoleAppRoute do
  use Ecto.Schema
  import Ecto.Changeset

  schema "role_app_route" do
    belongs_to(:app_route, BlogEngine.Settings.AppRoute)
    belongs_to(:role, BlogEngine.Settings.Role)
    # field :app_route_id, :integer
    # field :role_id, :integer

    timestamps()
  end

  @doc false
  def changeset(role_app_route, attrs) do
    role_app_route
    |> cast(attrs, [:role_id, :app_route_id])
    |> validate_required([:role_id, :app_route_id])
  end
end
