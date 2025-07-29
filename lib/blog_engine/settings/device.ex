defmodule BlogEngine.Settings.Device do
  use Ecto.Schema
  import Ecto.Changeset

  schema "devices" do
    field(:is_active, :boolean, default: false)
    field(:is_suspended, :boolean, default: false)
    field(:name, :string)
    field(:label, :string)
    field(:short_name, :string)
    field(:qr_code_data, :binary)
    field(:is_cloridge, :boolean, default: false)
    field(:cloridge_device_uid, :string)
    field(:default_delay, :float, default: 0.1)
    field(:format, :string, default: "pwm")
    field(:record_wifi_time, :boolean, default: false)
    field(:use_http_polling, :boolean, default: false)
    field(:short_desc, :string)
    belongs_to(:outlet, BlogEngine.Settings.Outlet)
    field(:default_io_pin, :integer, default: 0)

    field(:is_rs232, :boolean, default: false)
    field(:is_round_down, :boolean, default: true)
    field(:keep_pending_task, :boolean, default: true)
    field(:reading_pin, :integer, default: 16)
    belongs_to(:executor_board, BlogEngine.Settings.Device, foreign_key: :executor_board_id)

    belongs_to(:organization, BlogEngine.Settings.Organization)
    field(:skip_first, :boolean, default: false)
    timestamps()
  end

  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [
      :use_http_polling,
      :is_rs232,
      :is_round_down,
      :keep_pending_task,
      :reading_pin,
      :label,
      :default_delay,
      :organization_id,
      :short_name,
      :qr_code_data,
      :is_cloridge,
      :cloridge_device_uid,
      :format,
      :skip_first,
      :record_wifi_time,
      :executor_board_id,
      :outlet_id,
      :default_io_pin,
      :name,
      :short_desc,
      :is_active,
      :is_suspended
    ])

    # |> validate_required([:name, :short_desc, :is_active, :is_suspended])
  end
end
