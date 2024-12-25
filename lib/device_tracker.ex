defmodule DeviceTracker do
  @moduledoc """
  Tracks IoT devices' last online times using ETS.
  """

  @table_name :device_last_seen

  # Start the ETS table
  def start_link do
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  # Update the last online time for a device
  def update_last_online(uuid) do
    timestamp = DateTime.utc_now()
    :ets.insert(@table_name, {uuid, timestamp})
  end

  # Fetch the last online time for a device
  def get_last_online(uuid) do
    case :ets.lookup(@table_name, uuid) do
      [{^uuid, timestamp}] -> {:ok, timestamp}
      [] -> {:error, :not_found}
    end
  end
end
