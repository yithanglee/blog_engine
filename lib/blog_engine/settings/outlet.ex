defmodule BlogEngine.Settings.Outlet do
  use Ecto.Schema
  import Ecto.Changeset

  schema "outlets" do
    field(:address, :string)
    field(:subdomain, :string)
    field(:block_reason, :string)
    field(:is_blocked, :boolean, default: false)
    field(:name, :string)
    field(:uid, :string)
    field(:mkey, :string)
    field(:mcode, :string)
    field(:phone, :string)
    field(:email, :string)
    field(:collection_id, :string)
    field(:lat, :float)
    field(:lng, :float)
    field(:operating_hours_start, :time)
    field(:operating_hours_end, :time)
    belongs_to(:organization, BlogEngine.Settings.Organization)
    field(:price_per_minutes, :float, default: 0.5)
    field(:payment_gateway, :string)
    field(:currency, :string, default: "MYR")
    has_many(:devices, BlogEngine.Settings.Device)
    timestamps()
  end

  @doc false
  def changeset(outlet, attrs) do
    outlet
    |> cast(attrs, [
      :currency,
      :organization_id,
      :price_per_minutes,
      :collection_id,
      :mkey,
      :mcode,
      :phone,
      :email,
      :payment_gateway,
      :subdomain,
      :uid,
      :name,
      :address,
      :lat,
      :lng,
      :is_blocked,
      :block_reason,
      :operating_hours_start,
      :operating_hours_end
    ])

    # |> validate_required([:name, :address, :is_blocked, :block_reason])
  end
end
