defmodule BlogEngineWeb.OrganizationChannel do
  @moduledoc """
  Organization-scoped support room: members and staff of the same organization
  can exchange chat messages. Members receive their recent top-up transactions on join.
  """
  use BlogEngineWeb, :channel

  alias BlogEngine.Settings
  alias BlogEngine.Settings.{Staff, User, UserTopupTransaction}

  @impl true
  def join("organization:" <> org_id_str, %{"token" => token}, socket)
      when is_binary(token) and token != "" do
    with {:ok, org_id} <- parse_org_id(org_id_str),
         {:ok, auth} <- authenticate_token(token),
         true <- authorized_for_org?(auth, org_id) do
      recent = recent_transactions_for_join(auth, org_id)
      maybe_fcm_notify_operators_member_joined(auth, org_id)

      socket =
        socket
        |> assign(:organization_id, org_id)
        |> assign(:auth, auth)

      {:ok, %{recent_transactions: recent}, socket}
    else
      _ -> {:error, %{reason: "unauthorized"}}
    end
  end

  def join("organization:" <> _, _, _socket), do: {:error, %{reason: "unauthorized"}}

  @impl true
  def handle_in("chat_message", %{"body" => body}, socket) when is_binary(body) do
    trimmed = String.trim(body)

    if trimmed != "" do
      broadcast(socket, "chat_message", %{
        body: trimmed,
        sender: format_sender(socket.assigns.auth),
        at: DateTime.utc_now() |> DateTime.to_iso8601()
      })
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

  defp parse_org_id(str) do
    case Integer.parse(str) do
      {n, ""} -> {:ok, n}
      _ -> :error
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
            case Settings.get_staff_by_username(username) do
              nil -> :error
              %Staff{} = s -> {:ok, {:staff, s}}
            end

          _ ->
            :error
        end
    end
  end

  defp authorized_for_org?({:member, %User{organization_id: oid}}, org_id)
       when is_integer(oid) and is_integer(org_id),
       do: oid == org_id

  defp authorized_for_org?({:staff, %Staff{organization_id: oid}}, org_id)
       when is_integer(oid) and is_integer(org_id),
       do: oid == org_id

  defp authorized_for_org?(_, _), do: false

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
    %{role: "member", label: user_label(u), user_id: u.id}
  end

  defp format_sender({:staff, %Staff{} = s}) do
    %{role: "staff", label: staff_label(s), staff_id: s.id}
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
