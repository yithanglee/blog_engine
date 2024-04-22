defmodule BlogEngine.Settings.AppRoute do
  use Ecto.Schema
  import Ecto.Changeset

  schema "app_routes" do
    field(:can_get, :boolean, default: false)
    field(:can_post, :boolean, default: false)
    field(:desc, :string)
    field(:icon, :string)
    field(:name, :string)
    field(:parent_id, :integer)
    field(:route, :string)

    has_many(:role_app_routes, BlogEngine.Settings.RoleAppRoute)

    timestamps()
  end

  @doc false
  def changeset(app_route, attrs) do
    app_route
    |> cast(attrs, [:name, :icon, :route, :parent_id, :desc, :can_get, :can_post])

    # |> validate_required([:name, :icon, :route, :parent_id, :desc, :can_get, :can_post])
  end
end
