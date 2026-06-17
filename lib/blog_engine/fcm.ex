defmodule BlogEngine.Fcm do
  @moduledoc false

  import Ecto.Query, warn: false

  alias BlogEngine.Repo
  alias BlogEngine.Settings.MessagingDevice
  alias BlogEngine.Settings.User

  @firebase_dir "priv/static/firebase"
  @legacy_main_path "priv/static/service-account.json"
  @service_account_filename "service-account.json"
  @profile_meta_filename "fcm.json"
  @required_profile "main"

  @doc """
  Loads service account JSON files and returns `{profiles_map, goth_child_specs}`.

  Each Firebase app lives in its own folder under `priv/static/firebase/<profile>/`.
  The folder name is the profile key you pass to `publish/5` (e.g. `"main"`, `"hub"`).

  Expected layout:

      priv/static/firebase/
        main/
          service-account.json
          fcm.json                 # optional
        hub/
          service-account.json
          fcm.json                 # optional

  `fcm.json` may set `invalidate_token` to `messaging_device`, `user_fcm_token`, or `none`.
  Defaults: `"main"` clears `messaging_devices`; other profiles clear `users.fcm_token`.

  Legacy `priv/static/service-account.json` is still accepted as profile `"main"`.
  """
  def boot do
    profiles_from_dirs = load_profiles_from_dirs()

    {profiles, children} =
      profiles_from_dirs
      |> Enum.reduce({%{}, []}, fn {profile_key, profile, child}, {profiles, children} ->
        {Map.put(profiles, profile_key, profile), children ++ [child]}
      end)

    legacy_main_path = legacy_main_account_path()

    {profiles, children} =
      if Map.has_key?(profiles, @required_profile) or not File.exists?(legacy_main_path) do
        {profiles, children}
      else
        {profile_key, profile, child} = load_profile(@required_profile, legacy_main_path)
        {Map.put(profiles, profile_key, profile), children ++ [child]}
      end

    if not Map.has_key?(profiles, @required_profile) do
      raise """
      Missing required FCM profile #{inspect(@required_profile)}.

      Place the main service account at either:
        #{accounts_dir()}/#{@required_profile}/#{@service_account_filename}
        #{legacy_main_path}
      """
    end

    {profiles, children}
  end

  @doc """
  Sends an FCM notification using the given profile key (folder name under `priv/static/firebase/`).
  """
  def publish(profile_key, id, title, body, device_token)
      when is_binary(profile_key) and is_binary(device_token) do
    token = String.trim(device_token)

    if token == "" do
      :ok
    else
      case profile(profile_key) do
        nil ->
          require Logger

          Logger.warning(
            "FCM profile #{inspect(profile_key)} is not configured (missing service account folder)"
          )

          :ok

        %{goth: goth, project_id: project_id, invalidate_token: invalidate} ->
          access_token = Goth.fetch!(goth).token

          message = %{
            "message" => %{
              "token" => token,
              "notification" => %{
                "title" => title,
                "body" => body
              },
              "data" => %{
                "id" => "#{id}",
                "path" => "orders",
                "created_at" => Date.utc_today(),
                "click_action" => "FLUTTER_NOTIFICATION_CLICK"
              }
            }
          }

          url = "https://fcm.googleapis.com/v1/projects/#{project_id}/messages:send"

          case HTTPoison.post(
                 url,
                 Jason.encode!(message),
                 [
                   {"content-type", "application/json"},
                   {"Authorization", "Bearer #{access_token}"}
                 ]
               ) do
            {:ok, %HTTPoison.Response{body: response_body}} ->
              keys = Jason.decode!(response_body) |> Map.keys()

              if "error" in keys do
                invalidate_token(invalidate, token)
              end

              :ok

            _ ->
              :ok
          end
      end
    end
  end

  def publish(profile_key, _id, _title, _body, nil) when is_binary(profile_key), do: :ok

  def publish(profile_key, id, title, body, device_token)
      when is_atom(profile_key) and is_binary(device_token) do
    publish(to_string(profile_key), id, title, body, device_token)
  end

  def publish(profile_key, _id, _title, _body, nil) when is_atom(profile_key),
    do: publish(to_string(profile_key), 0, "", "", nil)

  defp accounts_dir do
    Application.app_dir(:blog_engine) <> "/#{@firebase_dir}"
  end

  defp legacy_main_account_path do
    Application.app_dir(:blog_engine) <> "/#{@legacy_main_path}"
  end

  defp load_profiles_from_dirs do
    base = accounts_dir()

    if File.dir?(base) do
      base
      |> File.ls!()
      |> Enum.filter(&valid_profile_folder?/1)
      |> Enum.sort()
      |> Enum.map(fn profile_key ->
        path = Path.join([base, profile_key, @service_account_filename])
        load_profile(profile_key, path)
      end)
    else
      []
    end
  end

  defp valid_profile_folder?(name) do
    name =~ ~r/^[a-z0-9][a-z0-9_-]*$/ and
      File.regular?(Path.join([accounts_dir(), name, @service_account_filename]))
  end

  defp load_profile(profile_key, service_account_path) do
    json = service_account_path |> File.read!() |> Jason.decode!()
    source = {:service_account, json}
    project_id = json["project_id"]
    goth = goth_name(profile_key)
    invalidate_token = read_invalidate_token(profile_key)

    profile = %{
      goth: goth,
      project_id: project_id,
      invalidate_token: invalidate_token
    }

    child = {Goth, name: goth, source: source}
    {profile_key, profile, child}
  end

  defp goth_name(profile_key) do
    :"BlogEngine.Goth.#{profile_key}"
  end

  defp read_invalidate_token(profile_key) do
    meta_path = Path.join([accounts_dir(), profile_key, @profile_meta_filename])

    default =
      if profile_key == @required_profile do
        :messaging_device
      else
        :user_fcm_token
      end

    if File.exists?(meta_path) do
      meta_path
      |> File.read!()
      |> Jason.decode!()
      |> Map.get("invalidate_token", Atom.to_string(default))
      |> parse_invalidate_token()
    else
      default
    end
  end

  defp parse_invalidate_token("messaging_device"), do: :messaging_device
  defp parse_invalidate_token("user_fcm_token"), do: :user_fcm_token
  defp parse_invalidate_token("none"), do: :none
  defp parse_invalidate_token(_), do: :none

  defp profile(profile_key) do
    Application.get_env(:blog_engine, :fcm_profiles, %{})
    |> Map.get(profile_key)
  end

  defp invalidate_token(:messaging_device, device_token) do
    Repo.delete_all(from(md in MessagingDevice, where: md.uuid == ^device_token))
  end

  defp invalidate_token(:user_fcm_token, device_token) do
    Repo.update_all(from(u in User, where: u.fcm_token == ^device_token), set: [fcm_token: nil])
  end

  defp invalidate_token(:none, _device_token), do: :ok
end
