defmodule BlogEngine.Settings.Role do
  use Ecto.Schema
  import Ecto.Changeset

  schema "roles" do
    field(:desc, :string)
    field(:name, :string)
    has_many(:role_app_route, BlogEngine.Settings.RoleAppRoute)
    has_many(:app_routes, through: [:role_app_route, :app_route])

    timestamps()
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :desc])

    # |> validate_required([:name, :desc])
  end
end
