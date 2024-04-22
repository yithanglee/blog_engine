defmodule BlogEngineWeb.UserChannel do
  use BlogEngineWeb, :channel

  @impl true
  def join("user:" <> room_id, payload, socket) do
    IO.inspect("room #{room_id}")
    IO.inspect(payload)

    if authorized?(payload) do
      socket = socket |> assign(:device_name, payload |> Map.get("name", "unknown"))
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

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    IO.inspect(payload)

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
  def handle_in("i_am", payload, socket) do
    IO.inspect(socket)

    dt =
      Timex.now()
      |> Timex.Timezone.convert("GMT+8")
      |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:{m}:{s}")

    BlogEngine.send_sqs(%{
      "scope" => "register",
      "name" => socket.assigns.device_name,
      "uuid" => payload["uuid"],
      "last_updated" => dt
    })

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

  @impl true
  def handle_in("get_question", payload, socket) do
    broadcast(socket, "get_question", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("question", payload, socket) do
    broadcast(socket, "question", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("answer", payload, socket) do
    broadcast(socket, "answer", payload)
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(payload) do
    IO.inspect("ws auth")
    IO.inspect(payload)
    true
  end
end
