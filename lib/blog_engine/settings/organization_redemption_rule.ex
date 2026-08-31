defmodule BlogEngine.Settings.OrganizationRedemptionRule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "organization_redemption_rules" do
    field :name, :string
    field :description, :string
    field :points_required, :float, default: 0.0
    field :reward_amount, :float, default: 0.0
    field :voucher_prefix, :string, default: "REW"
    field :voucher_expiry_days, :integer, default: 30
    field :is_active, :boolean, default: true

    belongs_to :organization, BlogEngine.Settings.Organization

    timestamps()
  end

  @doc false
  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [
      :name,
      :description,
      :points_required,
      :reward_amount,
      :voucher_prefix,
      :voucher_expiry_days,
      :is_active,
      :organization_id
    ])
    |> validate_required([:name, :points_required, :reward_amount, :organization_id])
  end
end
