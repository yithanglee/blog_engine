defmodule BlogEngineWeb.OrganizationChannel do
  @moduledoc """
  Organization-scoped support room: members and staff of the same organization
  can exchange chat messages. Members receive their recent top-up transactions on join.
  """
  use BlogEngineWeb, :channel

  alias BlogEngine.Settings
  alias BlogEngine.Settings.{OrganizationChatMessage, Staff, User, UserTopupTransaction}

  @impl true
  def join("organization:" <> topic_str, %{"token" => token}, socket)
      when is_binary(token) and token != "" do
    with {:ok, org_id, target_user_id} <- parse_topic(topic_str),
         {:ok, auth} <- authenticate_token(token),
         true <- authorized_for_topic?(auth, org_id, target_user_id) do
      chat_user_id =
        target_user_id ||
          case auth do
            {:member, %User{id: uid}} -> uid
            _ -> nil
          end

      recent = recent_transactions_for_join(auth, org_id)
      messages = recent_chat_messages_for_join(org_id, chat_user_id, auth)
      maybe_fcm_notify_operators_member_joined(auth, org_id)

      socket =
        socket
        |> assign(:organization_id, org_id)
        |> assign(:chat_user_id, chat_user_id)
        |> assign(:auth, auth)

      {:ok, %{recent_transactions: recent, messages: messages}, socket}
    else
      _ -> {:error, %{reason: "unauthorized"}}
    end
  end

  def join("organization:" <> _, _, _socket), do: {:error, %{reason: "unauthorized"}}

  @impl true
  def handle_in("chat_message", %{"body" => body}, socket) when is_binary(body) do
    trimmed = String.trim(body)

    if trimmed != "" do
      org_id = socket.assigns.organization_id
      chat_user_id = Map.get(socket.assigns, :chat_user_id)
      auth = socket.assigns.auth
      sender = format_sender(auth)

      db_user_id = sender[:user_id] || chat_user_id

      attrs = %{
        organization_id: org_id,
        body: trimmed,
        sender_role: sender[:role],
        sender_label: sender[:label],
        user_id: db_user_id,
        staff_id: sender[:staff_id]
      }

      case Settings.create_organization_chat_message(attrs) do
        {:ok, msg} ->
          broadcast(socket, "chat_message", %{
            body: msg.body,
            sender: sender,
            at: datetime_to_iso(msg.inserted_at)
          })

        _ ->
          broadcast(socket, "chat_message", %{
            body: trimmed,
            sender: sender,
            at: DateTime.utc_now() |> DateTime.to_iso8601()
          })
      end
    end

    {:noreply, socket}
  end

  def handle_in("chat_message", _, socket), do: {:noreply, socket}

  @doc """
  Staff-only: load recent `user_topup_transactions` for a member in the same organization
  (for support / refund context).

  Pass `query` (username or phone as the member knows it) and/or legacy `user_id`.
  Non-empty `query` is preferred over `user_id`.
  """
  def handle_in("member_support_context", params, socket) when is_map(params) do
    case socket.assigns.auth do
      {:staff, %Staff{}} ->
        org_id = socket.assigns.organization_id

        with true <- is_integer(org_id),
             {:ok, %User{} = member} <- resolve_support_member(params, org_id) do
          txs =
            member.id
            |> Settings.list_recent_user_topup_transactions(org_id, 20)
            |> Enum.map(&transaction_json/1)

          {:reply,
           {:ok,
            %{
              transactions: txs,
              member: member_support_summary(member)
            }}, socket}
        else
          {:error, :ambiguous} ->
            {:reply, {:error, %{reason: "ambiguous_member"}}, socket}

          _ ->
            {:reply, {:error, %{reason: "not_found_or_forbidden"}}, socket}
        end

      _ ->
        {:reply, {:error, %{reason: "staff_only"}}, socket}
    end
  end

  def handle_in("member_support_context", _, socket),
    do: {:reply, {:error, %{reason: "query_or_user_id_required"}}, socket}

  defp resolve_support_member(params, org_id) do
    q =
      case param_get(params, "query") do
        s when is_binary(s) -> String.trim(s)
        _ -> ""
      end

    cond do
      q != "" ->
        Settings.resolve_org_member_by_username_or_phone(org_id, q)

      true ->
        case param_get(params, "user_id") do
          nil ->
            {:error, :not_found}

          raw ->
            with {:ok, uid} <- parse_member_user_id(raw),
                 %User{organization_id: ^org_id} = u <- Settings.get_user!(uid) do
              {:ok, u}
            else
              _ -> {:error, :not_found}
            end
        end
    end
  end

  defp param_get(params, key) when is_map(params), do: Map.get(params, key)

  defp member_support_summary(%User{} = u) do
    %{
      id: u.id,
      username: u.username,
      phone: u.phone,
      fullname: u.fullname
    }
  end

  defp parse_member_user_id(v) when is_integer(v) and v > 0, do: {:ok, v}

  defp parse_member_user_id(v) when is_binary(v) do
    case Integer.parse(String.trim(v)) do
      {i, _} when i > 0 -> {:ok, i}
      _ -> :error
    end
  end

  defp parse_member_user_id(_), do: :error

  defp parse_topic(topic_str) do
    case String.split(topic_str, "_") do
      [org_str, user_str] ->
        with {org_id, ""} <- Integer.parse(org_str),
             {user_id, ""} <- Integer.parse(user_str) do
          {:ok, org_id, user_id}
        else
          _ -> :error
        end

      [org_str] ->
        case Integer.parse(org_str) do
          {org_id, ""} -> {:ok, org_id, nil}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp authenticate_token(token) do
    case Settings.decode_token(token) do
      %{id: uid} when is_integer(uid) ->
        case Settings.get_user!(uid) do
          nil -> :error
          %User{} = u -> {:ok, {:member, u}}
        end

      _ ->
        case Settings.decode_admin_token(token) do
          username when is_binary(username) ->
            find_staff_by_username(username)

          %{username: username} when is_binary(username) ->
            find_staff_by_username(username)

          %{"username" => username} when is_binary(username) ->
            find_staff_by_username(username)

          %{id: staff_id} when is_integer(staff_id) ->
            find_staff_by_id(staff_id)

          %{"id" => staff_id} when is_integer(staff_id) ->
            find_staff_by_id(staff_id)

          _ ->
            :error
        end
    end
  end

  defp find_staff_by_username(username) do
    case Settings.get_staff_by_username(username) do
      nil -> :error
      %Staff{} = s -> {:ok, {:staff, s}}
    end
  end

  defp find_staff_by_id(staff_id) do
    try do
      case Settings.get_staff!(staff_id) do
        nil -> :error
        %Staff{} = s -> {:ok, {:staff, s}}
      end
    catch
      _, _ -> :error
    end
  end

  defp authorized_for_topic?({:member, %User{id: uid, organization_id: oid}}, org_id, target_user_id)
       when is_integer(oid) and is_integer(org_id) do
    cond do
      oid != org_id -> false
      target_user_id != nil and target_user_id != uid -> false
      true -> true
    end
  end

  defp authorized_for_topic?({:staff, %Staff{organization_id: oid}}, org_id, _target_user_id)
       when is_integer(oid) and is_integer(org_id),
       do: oid == org_id

  defp authorized_for_topic?(_, _, _), do: false

  defp maybe_fcm_notify_operators_member_joined({:member, %User{} = u}, org_id)
       when is_integer(org_id) do
    label = user_label(u)

    Task.start(fn ->
      Settings.fcm_notify_org_operators_member_joined(org_id, label, u.id)
    end)
  end

  defp maybe_fcm_notify_operators_member_joined(_, _), do: :ok

  defp recent_transactions_for_join({:member, %User{id: uid}}, org_id) do
    uid
    |> Settings.list_recent_user_topup_transactions(org_id, 5)
    |> Enum.map(&transaction_json/1)
  end

  defp recent_transactions_for_join({:staff, _}, _org_id), do: []

  intercept ["chat_message"]

  @impl true
  def handle_out("chat_message", payload, socket) do
    case socket.assigns.auth do
      {:staff, _} ->
        push(socket, "chat_message", payload)
        {:noreply, socket}

      {:member, %User{id: uid}} ->
        sender = Map.get(payload, :sender) || Map.get(payload, "sender") || %{}
        role = Map.get(sender, :role) || Map.get(sender, "role")
        sender_uid = Map.get(sender, :user_id) || Map.get(sender, "user_id")

        if role == "staff" or sender_uid == uid do
          push(socket, "chat_message", payload)
        end

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  defp recent_chat_messages_for_join(org_id, chat_user_id, _auth) when is_integer(chat_user_id) do
    org_id
    |> Settings.list_recent_organization_chat_messages_for_member(chat_user_id, 100)
    |> Enum.map(&format_chat_message_json/1)
  end

  defp recent_chat_messages_for_join(org_id, nil, {:staff, _}) do
    org_id
    |> Settings.list_recent_organization_chat_messages(100)
    |> Enum.map(&format_chat_message_json/1)
  end

  defp format_chat_message_json(%OrganizationChatMessage{} = m) do
    %{
      body: m.body,
      sender: format_sender_from_db_message(m),
      at: datetime_to_iso(m.inserted_at)
    }
  end

  defp format_sender_from_db_message(%OrganizationChatMessage{sender_role: "member", user: %User{} = u} = m) do
    %{
      role: "member",
      label: m.sender_label || user_label(u),
      user_id: m.user_id,
      username: u.username,
      phone: u.phone
    }
  end

  defp format_sender_from_db_message(%OrganizationChatMessage{sender_role: "member"} = m) do
    %{
      role: "member",
      label: m.sender_label || "Member",
      user_id: m.user_id
    }
  end

  defp format_sender_from_db_message(%OrganizationChatMessage{sender_role: "staff", staff: %Staff{} = s} = m) do
    %{
      role: "staff",
      label: m.sender_label || staff_label(s),
      staff_id: m.staff_id
    }
  end

  defp format_sender_from_db_message(%OrganizationChatMessage{} = m) do
    %{
      role: m.sender_role || "participant",
      label: m.sender_label || "Participant",
      user_id: m.user_id,
      staff_id: m.staff_id
    }
  end

  defp transaction_json(%UserTopupTransaction{} = t) do
    %{
      id: t.id,
      amount: t.amount,
      before_amt: t.before_amt,
      after_amt: t.after_amt,
      remarks: t.remarks,
      user_id: t.user_id,
      sales_id: t.sales_id,
      inserted_at: datetime_to_iso(t.inserted_at)
    }
  end

  defp datetime_to_iso(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
  defp datetime_to_iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp datetime_to_iso(_), do: nil

  defp format_sender({:member, %User{} = u}) do
    %{
      role: "member",
      label: user_label(u),
      user_id: u.id,
      username: u.username,
      phone: u.phone
    }
  end

  defp format_sender({:staff, %Staff{} = s}) do
    %{
      role: "staff",
      label: staff_label(s),
      staff_id: s.id
    }
  end

  defp user_label(%User{fullname: n, username: u}) do
    cond do
      is_binary(n) and String.trim(n) != "" -> n
      is_binary(u) and String.trim(u) != "" -> u
      true -> "Member"
    end
  end

  defp staff_label(%Staff{name: n, username: u}) do
    cond do
      is_binary(n) and String.trim(n) != "" -> n
      is_binary(u) and String.trim(u) != "" -> u
      true -> "Staff"
    end
  end
end

