defmodule BlogEngineWeb.UserChannel do
  use BlogEngineWeb, :channel

  @impl true
  def join("user:" <> room_id, payload, socket) do
    IO.inspect("room #{room_id}")
    IO.inspect(payload)

    if authorized?(payload) do
      device =
        if payload |> Map.get("user_id") do
          d = BlogEngine.Settings.get_device_by_name(payload |> Map.get("user_id"))

          d
        else
          %{id: nil, current_firmware_version: nil, record_wifi_time: false}
        end
        |> IO.inspect(label: "device on join")

      socket =
        socket
        |> assign(:device_name, payload |> Map.get("name", "unknown"))
        |> assign(:uuid, payload |> Map.get("user_id", "unknown"))
        |> assign(:device_id, device.id)
        |> assign(:current_firmware_version, device.current_firmware_version)
        |> assign(:record_wifi_time, device.record_wifi_time)
      delay_start_outstanding_works(room_id)
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_in("screen-peer-message", %{"body" => body}, socket) do
    broadcast_from!(socket, "screen-peer-message", %{body: body})
    {:noreply, socket}
  end

  def handle_in("peer-message", %{"body" => body}, socket) do
    broadcast_from!(socket, "peer-message", %{body: body})
    {:noreply, socket}
  end

  @impl true
  def handle_in("pwm_readings", payload, socket) do
    device = BlogEngine.Settings.get_device_by_name(socket.assigns.uuid)

    BlogEngine.Settings.create_io_reading(%{
      device_id: device.id,
      log: Jason.encode!(payload),
      final_data: Map.get(payload, "pulse_count") |> Integer.to_string()
    })
    |> IO.inspect()

    {:noreply, socket}
  end

  @doc """
  Get settings from the device
  """

  @impl true
  def handle_in("get_settings", payload, socket) do
    device = BlogEngine.Settings.get_device_by_name(socket.assigns.uuid)

    is_bill_acceptor = fn ->
      if device.is_rs232 do
        "bill_acceptor"
      else
        "pwm_machine"
      end
    end

    broadcast(socket, "settings_response", %{
      rs232_config: %{
        device_type: is_bill_acceptor.()
      },
      pwm_config: %{input_pin: device.reading_pin}
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("pwm_response", payload, socket) do
    device = BlogEngine.Settings.get_device_by_name(socket.assigns.uuid)

    BlogEngine.Settings.create_device_log(%{
      device_id: device.id,
      uuid: payload["uuid"],
      remarks: "completed manual start #{payload["reps"]}"
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("ping", payload, socket) do
    if socket.assigns.device_id != nil do
      Elixir.Task.start_link(BlogEngine.Settings, :create_device_time_log, [
        %{device_id: socket.assigns.device_id}
      ])
    else
      IO.inspect("the device id was not assigned here..")
    end
    # if socket.assigns.device_id != nil do
    #     if socket.assigns.record_wifi_time do
    #     Elixir.Task.start_link(BlogEngine.Settings, :create_device_time_log, [
    #         %{device_id: socket.assigns.device_id}
    #       ])
    #     end
    # else
    #   IO.inspect("the device id was not assigned here..")
    # end
    socket =
      if Map.get(payload, "firmware_version") != socket.assigns.current_firmware_version do
        IO.inspect("firmware version mismatch")
        device = BlogEngine.Settings.get_device_by_name(socket.assigns.uuid) |> IO.inspect(label: "device")

        case BlogEngine.Settings.update_device(device, %{
               current_firmware_version: Map.get(payload, "firmware_version")
             }) do
          {:ok, _} ->
            socket
            |> assign(:current_firmware_version, Map.get(payload, "firmware_version"))

          {:error, _} ->
            socket
        end
      else
        socket
      end

    broadcast(socket, "i_am_online", payload)
    {:reply, {:ok, payload}, socket}
  end

  @impl true
  def handle_in("ask_initiate", payload, socket) do
    IO.inspect("ask initiate")
    IO.inspect(payload)

    broadcast(socket, "initiate", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("ota_status", payload, socket) do
    IO.inspect("📡 OTA Status Update from ESP32:")
    IO.inspect(payload)

    device = BlogEngine.Settings.get_device_by_name(socket.assigns.uuid)

    if device do
      # Log the OTA status update
      BlogEngine.Settings.create_firmware_log(%{
        device_id: device.id,
        action: "status_update_#{payload["status"]}",
        version: payload["target_version"] || payload["current_version"] || "unknown"
      })

      # Update device current firmware version if OTA completed successfully
      if payload["status"] == "complete" && payload["target_version"] do
        BlogEngine.Settings.update_device(device, %{
          current_firmware_version: payload["target_version"]
        })

        IO.inspect("✅ Device firmware version updated to: #{payload["target_version"]}")
      end

      # Broadcast status to any listeners (like web dashboard)
      broadcast(socket, "ota_status_update", payload)
    else
      IO.inspect("⚠️ Device not found for OTA status update")
    end

    {:noreply, socket}
  end

  @impl true
  def handle_in("ota_update", payload, socket) do
    IO.inspect("📡 Received OTA Update Command:")
    IO.inspect(payload)

    # This handles OTA commands sent from the API to the ESP32
    # The ESP32 should receive this and start the OTA process
    broadcast(socket, "ota_update", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("i_am", payload, socket) do
    IO.inspect(socket)

    dt =
      Timex.now()
      |> Timex.Timezone.convert("GMT+8")
      |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:{m}:{s}")

    {:noreply, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (user:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("http_client", payload, %{topic: topic} = socket) do
    receiver = topic |> String.replace("user:", "")
    pid = Process.whereis(:ngrok)

    with true <- pid != nil do
      Agent.update(pid, fn map -> Map.put(map, receiver, payload["body"]) end)
    else
      _ ->
        ""
    end

    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(%{"user_id" => user_id} = payload) do
    IO.inspect("ws auth for #{user_id}")

    is_blocked =
      Cachex.fetch!(:device_blocked_cache, user_id, fn _key ->
        device = BlogEngine.Settings.create_update_device(payload)
        device.is_blocked
      end, ttl: :timer.minutes(5))

    !is_blocked
  end

  defp authorized?(_payload) do
    IO.inspect("ws auth - no user_id")
    true
  end

  defp delay_start_outstanding_works(uuid) do
    Process.sleep(2000)
    Elixir.Task.start_link(BlogEngine.Settings, :get_outstanding_works, [uuid])
  end
end
