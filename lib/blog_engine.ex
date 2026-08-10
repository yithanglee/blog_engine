defmodule BlogEngine do
  import Ecto.Query
  alias BlogEngine.{Settings, Repo}

  @moduledoc """
  BlogEngine keeps the contexts that define your domain
  and business logic.
  BlogEnging.check_online()

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def check_online(params \\ "") do
    admins =
      Repo.all(
        from(s in Settings.Staff,
          left_join: r in Settings.Role,
          on: r.id == s.role_id,
          left_join: md in Settings.MessagingDevice,
          on: md.staff_id == s.id,
          where: r.name in ^["Owner", "Admin", "admin"],
          where: not is_nil(md.uuid),
          select: %{uuid: md.uuid, organization_id: s.organization_id}
        )
      )
      |> IO.inspect(label: "admins")

    device_ids =
      Repo.all(
        from(d in Settings.Device,
          left_join: o in Settings.Outlet,
          on: o.id == d.outlet_id,
          left_join: og in Settings.Organization,
          on: og.id == d.organization_id,
          left_join: s in Settings.Staff,
          on: s.organization_id == og.id,
          left_join: md in Settings.MessagingDevice,
          on: md.staff_id == s.id,
          where: d.is_active == true,
          select: %{
            id: d.id,
            label: d.label,
            outlet_name: o.name,
            uuid: md.uuid,
            organization_id: d.organization_id
          }
        )
      )
      |> IO.inspect(label: "devices")

    for %{id: id, label: label, outlet_name: outlet_name, uuid: uuid, organization_id: org_id} <-
          device_ids do
      timestamp = DateTime.utc_now() |> DateTime.add(8 * 60 * 60) |> DateTime.to_iso8601()

      case DeviceTracker.get_last_online(id) do
        {:ok, last_online} ->
          nil
          diff = DateTime.utc_now() |> DateTime.diff(last_online) |> IO.inspect(label: "diff")

          if true do
            profile = BlogEngine.Settings.get_fcm_profile_by_org_id(org_id)
            IO.inspect(uuid, label: "uuid")

            Elixir.Task.start_link(BlogEngine.Settings, :fcm_publish, [
              0,
              "Device Online Checker",
              "#{outlet_name}'s #{label} is not online. Checked #{timestamp} ",
              uuid,
              [profile: profile]
            ])

            for %{uuid: admin_uuid, organization_id: admin_org_id} <- admins do
              admin_profile = BlogEngine.Settings.get_fcm_profile_by_org_id(admin_org_id)

              Elixir.Task.start_link(BlogEngine.Settings, :fcm_publish, [
                0,
                "Device Online Checker",
                "#{outlet_name}'s #{label} is not online. Checked #{timestamp}",
                admin_uuid,
                [profile: admin_profile]
              ])
            end
          end

          diff

        _ ->
          IO.inspect("no notification")
          nil
      end
    end
  end

  def encode_params(params) do
    encode_value = fn tuple ->
      case tuple do
        {key, value} when is_map(value) ->
          {key, URI.encode_query(value)}

        {key, value} ->
          {key, value}
      end
    end

    params
    |> Enum.map(&encode_value.(&1))
    |> URI.encode_query()
  end

  def _send_sqs(map \\ %{"scope" => "register", "name" => "John", "age" => 30}) do
    params =
      %{
        "Action" => "SendMessage",
        "MessageBody" => Jason.encode!(map)
      }
      |> IO.inspect()

    query_string =
      encode_params(params)
      |> IO.inspect()

    case HTTPoison.post(
           "http://localhost:9324/queue/queue1",
           query_string,
           [{"Content-Type", "application/x-www-form-urlencoded"}]
         ) do
      {:ok,
       %HTTPoison.Response{
         body: body
       } = _res} ->
        body |> IO.puts()

      _ ->
        nil
    end
  end

  def write_json(bin, filename) do
    check = File.exists?(File.cwd!() <> "/media")

    path =
      if check do
        File.cwd!() <> "/media"
      else
        File.mkdir(File.cwd!() <> "/media")
        File.cwd!() <> "/media"
      end

    File.rm_rf("./priv/static/images/uploads")
    File.ln_s("#{File.cwd!()}/media/", "./priv/static/images/uploads")

    File.rm_rf("#{path}/#{filename}")
    File.touch("#{path}/#{filename}")

    IO.inspect("writing into... #{path} #{filename}")

    File.write("#{path}/#{filename}", bin)
  end

  def eval_codes(singular, plural) do
    struct =
      singular |> String.split("_") |> Enum.map(&(&1 |> String.capitalize())) |> Enum.join("")

    dynamic_code =
      """
        alias BlogEngine.Settings.#{struct}
        def list_#{plural}() do
          Repo.all(#{struct})
        end
        def get_#{singular}!(id) do
          Repo.get!(#{struct}, id)
        end
        def create_#{singular}(params \\\\ %{}) do
          #{struct}.changeset(%#{struct}{}, params) |> Repo.insert() |> IO.inspect()
        end
        def update_#{singular}(model, params) do
          #{struct}.changeset(model, params) |> Repo.update() |> IO.inspect()
        end
        def delete_#{singular}(%#{struct}{} = model) do
          Repo.delete(model)
        end

        random_id = makeid(4)
        #{singular}Source = new phoenixModel({
          columns: [

            { label: 'id', data: 'id' },
            { label: 'Action', data: 'id' }

          ],
          moduleName: "#{struct}",
          link: "#{struct}",
          customCols: customCols,
          buttons: [{
            buttonType: "grouped",
            name: "Manage",
            color: "outline-warning",
            buttonList: [

              {
                name: "Edit",
                iconName: "fa fa-edit",
                color: "btn-sm btn-outline-warning",
                onClickFunction: editData,
                fnParams: {
                  drawFn: enlargeModal,
                  customCols: customCols
                }
              },
              {
                name: "Delete",
                iconName: "fa fa-trash",
                color: "outline-danger",
                onClickFunction: deleteData,
                fnParams: {}
              }
            ],
            fnParams: {

            }
            }, ],
          tableSelector: "#" + random_id
        })
        #{singular}Source.load(random_id, "#tab1")



          function call#{struct}() {
            #{singular}Source2 = new phoenixModel({
              columns: [{
                  label: 'Name',
                  data: 'name'
                },
                {
                  label: 'Action',
                  data: 'id'
                }
              ],
              moduleName: "#{struct}",
              link: "#{struct}",
              buttons: [{
                name: "Select",
                iconName: "fa fa-check",
                color: "btn-sm btn-outline-success",
                onClickFunction: (params) => {
                  var dt = params.dataSource;
                  var table = dt.table;
                  var data = table.data()[params.index]
                  console.log(data.id)
                  $("input[name='Book[#{singular}][name]']").val(data.name)
                  $("input[name='Book[#{singular}][id]']").val(data.id)
                  $("input[name='Book[#{singular}_id]']").val(data.id)
                  $("#myModal").modal('hide')
                },
                fnParams: {

                }
              }, ],
              tableSelector: "#" + random_id
            })
            App.modal({
              selector: "#myModal",
              autoClose: false,
              header: "Search #{struct}",
              content: `
              <div id="#{singular}">

              </div>`
            })
            #{singular}Source2.load(makeid(4), '##{singular}')
            #{singular}Source2.table.on("draw", function() {
              if ($("#search_user").length == 0) {
                $(".module_buttons").prepend(`
                  <label class="col-form-label " for="inputSmall">#{struct} </label>
                  <input class="mx-4 form-control form-control-sm" id="search_user"></input>
                            `)
              }
              $('input#search_user').on('change', function(e) {
                var query = $(this).val()
                #{singular}Source2.table
                  .columns(0)
                  .search(query)
                  .draw();
              })
            })
          }



      """
      |> IO.puts()
  end

  @doc """
  BlogEngine.eval_svt("stock_adjustment", "stock_adjustments", %{})
  """

  def eval_svt(
        singular,
        plural,
        opts \\ %{}
      ) do
    struct =
      singular |> String.split("_") |> Enum.map(&(&1 |> String.capitalize())) |> Enum.join("")

    relationship = opts |> Map.get(:relationship, :none)
    child_id = opts |> Map.get(:child_id)
    parent_module = opts |> Map.get(:parent_module)
    preloaded_parent = opts |> Map.get(:preloaded_parent)

    dynamic_code =
      case relationship do
        :many ->
          """
          /** @type {import('./$types').PageLoad} */

          import { genInputs, postData, buildQueryString } from '$lib/index.js';
          import { PHX_HTTP_PROTOCOL, PHX_ENDPOINT } from '$lib/constants';
          export const load = async ({ fetch, params, parent }) => {
          let url = PHX_HTTP_PROTOCOL + PHX_ENDPOINT ,module;

          let inputs = await genInputs(url, '#{struct}'), scope = "get_product_countries";

          const queryString = buildQueryString({ scope: scope, id: params["#{child_id}"] });
          const response = await fetch(url + '/svt_api/webhook?' + queryString, {
            headers: {
                  'Content-Type': 'application/json'
              }
          });
            if (response.ok) {
                let dataList = await response.json();
                return {
                    dataList: dataList,
                    #{child_id}: params['#{child_id}'],
                    module: '#{struct}',
                    inputs: inputs
                };
            }
          };



          // new lines


          <script>
            import Datatable from '$lib/components/Datatable.svelte';
            /** @type {import('./$types').PageData} */
            export let data;
            let inputs = data.inputs,
              dataList = data.dataList;
          </script>

          <Datatable
            data={{
              showNew: true,
              canDelete: true,
              appendQueries: { #{child_id}: data.#{child_id} },
              inputs: inputs,
              search_queries: null,
              model: '#{struct}',
              preloads: ['product', 'country'],
              customCols: [
                {
                  title: 'General',
                  list: [
                    'id',
                    {
                      label: '#{parent_module}',
                      selection: '#{parent_module}',
                      multiSelection: true,
                      dataList: dataList.#{preloaded_parent},
                      module: '#{parent_module}',
                      parentId: data.#{child_id},
                      parent_module: '#{struct}'
                    }
                  ]
                }
              ],
              columns: [
                { label: 'ID', data: 'id' },
                { label: 'Product', data: 'name', through: ['product'] },
                { label: 'Country', data: 'name', through: ['country'] }
                // { label: 'URL', data: 'route', through: ['app_route'] }
              ]
            }}
          />





          """

        _ ->
          """
          /** @type {import('./$types').PageLoad} */

          import { genInputs, postData, buildQueryString } from '$lib/index.js';
          import { PHX_HTTP_PROTOCOL, PHX_ENDPOINT } from '$lib/constants';
          export const load = async () => {
          let url = PHX_HTTP_PROTOCOL + PHX_ENDPOINT ,module;

          let inputs = await genInputs(url, '#{struct}')
            return {module: '#{struct}',
              inputs: inputs
            };
          };

          // new lines



          <script>
          import { PHX_HTTP_PROTOCOL, PHX_ENDPOINT } from '$lib/constants';
          import { goto } from '$app/navigation';
          import Datatable from '$lib/components/Datatable.svelte';
          import { buildQueryString, postData } from '$lib/index.js';
          /** @type {import('./$types').PageData} */
          export let data;

          let inputs = data.inputs;
          var url = PHX_HTTP_PROTOCOL + PHX_ENDPOINT;

          function downloadDO(data, checkPage, confirmModal) {
            window.open(url + '/pdf?type=do&id=' + data.id, '_blank').focus();
          }
          function viewDO(data, checkPage, confirmModal) {
            goto('/deliveries/' + data.id);
          }
          function showCondition(data) {
            var bool = false;
            if (data.status == 'processing') {
              bool = true;
            }
            return bool;
          }
          function showCondition2(data) {
            var bool = false;
            if (data.status == 'pending_delivery') {
              bool = true;
            }
            return bool;
          }
          function doMarkPendingDelivery(data, checkPage, confirmModal) {
            console.log(data);
            console.log('transfer approved!');

            confirmModal(true, 'Are you sure to mark this order as pending delivery?', () => {
              postData(
                { scope: 'mark_do', id: data.id, status: 'pending_delivery' },
                {
                  endpoint: url + '/svt_api/webhook',
                  successCallback: () => {
                    checkPage();
                  }
                }
              );
            });
          }
          function doMarkSent(data, checkPage, confirmModal) {
            console.log(data);
            console.log('transfer approved!');

            confirmModal(
              true,
              `
              <label class="my-4 text-sm font-medium block
              text-gray-900 dark:text-gray-300 space-y-2">
              <span>Shipping Ref</span>  <input name="shipping_ref"
              placeholder="" type="text" class="block w-75 disabled:cursor-not-allowed disabled:opacity-50 p-2.5 focus:border-primary-500 focus:ring-primary-500 dark:focus:border-primary-500 dark:focus:ring-primary-500 bg-gray-50 text-gray-900 dark:bg-gray-600 dark:text-white dark:placeholder-gray-400 border-gray-300 dark:border-gray-500 text-sm rounded-lg"> </label>
              <span class="">Are you sure to mark this order as sent?</span>`,
              () => {
                var dom = document.querySelector("input[name='shipping_ref']");
                postData(
                  { scope: 'mark_do', shipping_ref: dom.value, id: data.id, status: 'sent' },
                  {
                    endpoint: url + '/svt_api/webhook',
                    successCallback: () => {
                      checkPage();
                    }
                  }
                );
              }
            );
          }
          </script>

          <Datatable
          data={{
            inputs: inputs,
            join_statements: JSON.stringify([

              { user: 'user' }
            ]),
            search_queries: ['a.id|b.username|b.fullname'],
            model: 'Sale',
            preloads: ['user', 'sales_person', 'payment'],
            buttons: [
              { name: 'Preview', onclickFn: viewDO },
              { name: 'Download DO (PDF)', onclickFn: downloadDO },
              {
                name: 'Mark Pending Delivery',
                onclickFn: doMarkPendingDelivery,
                showCondition: showCondition
              },
              { name: 'Mark Sent', onclickFn: doMarkSent, showCondition: showCondition2 }
            ],
            customCols: [
              {
                title: 'Order',
                list: [
                  'id',
                  'shipping_method',
                  'shipping_company',
                  'shipping_ref',
                  { label: 'remarks', editor2: true },
                  {
                    label: 'role_id',
                    selection: 'Role',
                    module: 'Role',
                    customCols: null,
                    search_queries: ['a.name'],
                    newData: 'name',
                    title_key: 'name'
                  },
                ]
              }
            ],
            columns: [
              { label: 'ID', data: 'id' },
              { label: 'Timestamp', data: 'inserted_at', formatDateTime: true , offset: 8},

              {
                label: 'Status',
                data: 'status',
                isBadge: true,
                color: [
                  {
                    key: 'pending_payment',
                    value: 'yellow'
                  },
                  {
                    key: 'pending_confirmation',
                    value: 'yellow'
                  },
                  {
                    key: 'processing',
                    value: 'blue'
                  },
                  {
                    key: 'sent',
                    value: 'pink'
                  },
                  {
                    key: 'pending_delivery',
                    value: 'purple'
                  },
                  {
                    key: 'complete',
                    value: 'green'
                  }
                ]
              },
              { label: 'User', data: 'username', through: ['user'] },
              { label: 'Sales Person', data: 'username', through: ['sales_person'] }
            ]
          }}
          />


          """
      end
      |> IO.puts()
  end

  def _upload_file(params) do
    check_upload =
      Map.values(params)
      |> Enum.with_index()
      |> Enum.filter(fn x -> is_map(elem(x, 0)) end)
      |> Enum.filter(fn x -> :__struct__ in Map.keys(elem(x, 0)) end)
      |> Enum.filter(fn x -> elem(x, 0).__struct__ == Plug.Upload end)

    # Enum.reduce([1, 2, 3], 0, fn x, acc -> x + acc end)

    if check_upload != [] do
      upload_fn = fn check_upload_item, xparams ->
        file_plug = check_upload_item |> elem(0)
        index = check_upload_item |> elem(1)

        check = File.exists?(File.cwd!() <> "/media")

        path =
          if check do
            File.cwd!() <> "/media"
          else
            File.mkdir(File.cwd!() <> "/media")
            File.cwd!() <> "/media"
          end

        final =
          if is_map(file_plug) do
            IO.inspect(is_map(file_plug))
            fl = String.replace(file_plug.filename, "'", "")
            File.cp(file_plug.path, path <> "/#{fl}")
            "/images/uploads/#{fl}"
          else
            "/images/uploads/#{file_plug}"
          end

        Map.put(xparams, Enum.at(Map.keys(xparams), index), final)
      end

      Enum.reduce(check_upload, params, fn x, acc -> upload_fn.(x, acc) end)

      # for check_upload_item <- check_upload do
      # end
    else
      params
    end
  end

  def check_time_difference(date_to_check \\ Timex.shift(Timex.now(), hours: -100)) do
    duration = date_to_check |> Timex.diff(Timex.now(), :duration)

    duration
    |> Elixir.Timex.Format.Duration.Formatters.Humanized.format()
    |> String.split(",")
    |> List.first()
  end

  def upload_file(params) do
    check_upload =
      Map.values(params)
      |> Enum.with_index()
      |> Enum.filter(fn x -> is_map(elem(x, 0)) end)
      |> Enum.filter(fn x -> :__struct__ in Map.keys(elem(x, 0)) end)
      |> Enum.filter(fn x -> elem(x, 0).__struct__ == Plug.Upload end)

    # Enum.reduce([1, 2, 3], 0, fn x, acc -> x + acc end)

    IO.inspect(check_upload)

    upload_fn = fn check_upload_item, xparams ->
      file_plug = check_upload_item |> elem(0)
      index = check_upload_item |> elem(1)

      check = File.exists?(File.cwd!() <> "/media")

      path =
        if check do
          File.cwd!() <> "/media"
        else
          File.mkdir(File.cwd!() <> "/media")
          File.cwd!() <> "/media"
        end

      final =
        if is_map(file_plug) do
          IO.inspect(is_map(file_plug))
          fl = String.replace(file_plug.filename, "'", "")
          File.cp(file_plug.path, path <> "/#{fl}")
          "/images/uploads/#{fl}"
        else
          "/images/uploads/#{file_plug}"
        end

      Map.put(xparams, Enum.at(Map.keys(xparams), index), final)
    end

    if check_upload != [] do
      Enum.reduce(check_upload, params, fn x, acc -> upload_fn.(x, acc) end)
    else
      check_list = fn x, acc ->
        IO.inspect(x)
        acc
      end

      keys = params |> Map.keys()

      final =
        for key <- keys do
          val = params[key]

          val =
            if val |> is_list do
              sample = [
                %{
                  "img_url" => %Plug.Upload{
                    content_type: "image/png",
                    filename: "Screenshot from 2023-08-23 23-33-20.png",
                    path: "/tmp/plug-1693/multipart-1693554475-438950753586117-2"
                  }
                },
                %{
                  "img_url" => %Plug.Upload{
                    content_type: "image/png",
                    filename: "Screenshot from 2023-08-09 15-34-50.png",
                    path: "/tmp/plug-1693/multipart-1693554475-924374081231031-2"
                  }
                }
              ]

              for v <- val do
                check_upload2 = v |> Map.values() |> Enum.with_index()

                Enum.reduce(check_upload2, v, fn x, acc -> upload_fn.(x, acc) end)
              end
            else
              val
            end

          {key, val}
        end
        |> Enum.into(%{})

      # params
    end
    |> IO.inspect()
  end

  @doc """
  Sign in a **member** (`BlogEngine.Settings.User`) using Firebase Authentication.

  Links `firebase_auth_id` on first match by verified email. See `BlogEngine.Settings.sign_in_with_firebase/1`.
  """
  defdelegate sign_in_with_firebase(params), to: BlogEngine.Settings

  def translation() do
    data = File.read("translation.csv")

    case data do
      {:ok, line_data} ->
        lines = line_data |> String.split("\n") |> Enum.reject(&(&1 == ""))
        lines = {header, lines} = List.pop_at(lines, 0)
        header = String.split(header, ",")

        for item <- lines do
          items = String.split(item, ",")

          Enum.zip(header, items) |> Enum.into(%{})
        end

      _ ->
        %{}
    end
  end
end
