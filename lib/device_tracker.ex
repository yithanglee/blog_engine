defmodule DeviceTracker do
  @moduledoc """
  Tracks IoT devices' last online times using ETS.
  """

  @table_name :device_last_seen
  @notified_table :device_notified_offline

  # Start the ETS table
  def start_link do
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@notified_table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  # Update the last online time for a device
  def update_last_online(uuid) do
    timestamp = DateTime.utc_now()
    :ets.insert(@table_name, {uuid, timestamp})
    :ets.delete(@notified_table, uuid)
  end

  # Fetch the last online time for a device
  def get_last_online(uuid) do
    case :ets.lookup(@table_name, uuid) do
      [{^uuid, timestamp}] -> {:ok, timestamp}
      [] -> {:error, :not_found}
    end
  end

  # Mark device as notified of offline status
  def mark_notified_offline(uuid) do
    :ets.insert(@notified_table, {uuid, true})
  end

  # Check if device was already notified for this offline event
  def notified_offline?(uuid) do
    case :ets.lookup(@notified_table, uuid) do
      [{^uuid, true}] -> true
      _ -> false
    end
  end
end
