defmodule RadarWeb.RadarLive.Edit do
  use RadarWeb, :live_view

  alias Radar.TechRadar
  alias Radar.TechRadar.{Config, FrontMatterParser, FrontMatterWriter, HtmlConverter}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case TechRadar.get_item(id) do
      {:ok, item} ->
        {front_matter, body} = FrontMatterParser.parse(item.path, File.read!(item.path))
        form_params = form_params(front_matter, body)

        {:ok,
         socket
         |> assign(:page_title, "Edit #{item.title}")
         |> assign(:item, item)
         |> assign(:form, to_form(form_params, as: :item))
         |> assign(:preview_html, HtmlConverter.convert(nil, body, nil, nil))}

      :error ->
        {:ok,
         socket
         |> put_flash(:error, "That radar item couldn't be found.")
         |> push_navigate(to: ~p"/radar")}
    end
  end

  defp form_params(front_matter, body) do
    %{
      "title" => front_matter.title,
      "ring" => front_matter.ring,
      "quadrant" => front_matter.quadrant,
      "tags" => Enum.join(Map.get(front_matter, :tags, []), ", "),
      "featured" => to_string(Map.get(front_matter, :featured, true)),
      "related" => Enum.join(Map.get(front_matter, :related, []), ", "),
      "type" => Map.get(front_matter, :type, "Radar Item"),
      "status" => Map.get(front_matter, :status, "stable"),
      "stale_after" => Map.get(front_matter, :stale_after, ""),
      "sources" => Enum.join(Map.get(front_matter, :sources, []), ", "),
      "body" => body
    }
  end

  @impl true
  def handle_event("validate", %{"item" => params}, socket) do
    errors =
      case validate_attrs(params, socket.assigns.item) do
        {:ok, _attrs} -> []
        {:error, errors} -> errors
      end

    {:noreply,
     socket
     |> assign(:preview_html, HtmlConverter.convert(nil, params["body"] || "", nil, nil))
     |> assign(:form, to_form(params, as: :item, errors: errors))}
  end

  def handle_event("save", %{"item" => params}, socket) do
    item = socket.assigns.item

    case validate_attrs(params, item) do
      {:ok, attrs} ->
        File.write!(item.path, FrontMatterWriter.render(attrs, params["body"]))

        {:noreply,
         socket
         |> put_flash(:info, "Saved.")
         |> push_navigate(to: ~p"/radar/#{item.id}")}

      {:error, errors} ->
        {:noreply, assign(socket, :form, to_form(params, as: :item, errors: errors))}
    end
  end

  defp validate_attrs(params, item) do
    {attrs, errors} = {%{}, []}
    {attrs, errors} = put_text(attrs, errors, :title, params["title"])
    {attrs, errors} = put_text(attrs, errors, :type, params["type"])
    {attrs, errors} = put_allowlisted(attrs, errors, :ring, params["ring"], Config.ring_ids())

    {attrs, errors} =
      put_allowlisted(attrs, errors, :quadrant, params["quadrant"], Config.quadrant_ids())

    {attrs, errors} =
      put_allowlisted(attrs, errors, :status, params["status"], Config.status_ids())

    attrs = Map.put(attrs, :featured, params["featured"] == "true")
    {attrs, errors} = put_list(attrs, errors, :tags, params["tags"])
    {attrs, errors} = put_list(attrs, errors, :sources, params["sources"])
    {attrs, errors} = put_related(attrs, errors, params["related"], item)
    {attrs, errors} = put_stale_after(attrs, errors, params["stale_after"])
    errors = validate_body(errors, params["body"])

    if errors == [], do: {:ok, attrs}, else: {:error, errors}
  end

  defp put_text(attrs, errors, field, value) do
    value = String.trim(value || "")

    cond do
      value == "" ->
        {attrs, errors ++ [{field, {"can't be blank", []}}]}

      String.contains?(value, "\"") or String.contains?(value, "\n") ->
        {attrs, errors ++ [{field, {"can't contain a quote or newline", []}}]}

      true ->
        {Map.put(attrs, field, value), errors}
    end
  end

  defp put_allowlisted(attrs, errors, field, value, allowed_ids) do
    value = String.trim(value || "")

    case Enum.find(allowed_ids, &(Atom.to_string(&1) == value)) do
      nil ->
        allowed = Enum.map_join(allowed_ids, ", ", &Atom.to_string/1)
        {attrs, errors ++ [{field, {"must be one of #{allowed}", []}}]}

      match ->
        {Map.put(attrs, field, match), errors}
    end
  end

  defp put_list(attrs, errors, field, value) do
    items =
      (value || "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if Enum.any?(items, &String.match?(&1, ~r/[\[\]"]/)) do
      {attrs, errors ++ [{field, {"entries can't contain [, ], or \"", []}}]}
    else
      {Map.put(attrs, field, items), errors}
    end
  end

  defp put_related(attrs, errors, value, item) do
    ids =
      (value || "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    unknown = Enum.reject(ids -- [item.id], &match?({:ok, _}, TechRadar.get_item(&1)))

    cond do
      Enum.any?(ids, &String.match?(&1, ~r/[\[\]"]/)) ->
        {attrs, errors ++ [{:related, {"entries can't contain [, ], or \"", []}}]}

      item.id in ids ->
        {attrs, errors ++ [{:related, {"can't reference itself", []}}]}

      unknown != [] ->
        {attrs, errors ++ [{:related, {"unknown item ids: #{Enum.join(unknown, ", ")}", []}}]}

      true ->
        {Map.put(attrs, :related, ids), errors}
    end
  end

  defp put_stale_after(attrs, errors, value) do
    value = String.trim(value || "")

    cond do
      value == "" ->
        {Map.put(attrs, :stale_after, nil), errors}

      match?({:ok, _}, Date.from_iso8601(value)) ->
        {Map.put(attrs, :stale_after, value), errors}

      true ->
        {attrs, errors ++ [{:stale_after, {"must be a valid date (YYYY-MM-DD)", []}}]}
    end
  end

  defp validate_body(errors, value) do
    if String.trim(value || "") == "" do
      errors ++ [{:body, {"can't be blank", []}}]
    else
      errors
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="radar-item-edit">
        <.link
          navigate={~p"/radar/#{@item.id}"}
          class="text-sm text-base-content/70 hover:underline"
        >
          &larr; Back to {@item.title}
        </.link>

        <.header>Edit {@item.title}</.header>

        <.form
          for={@form}
          id="item-form"
          phx-change="validate"
          phx-submit="save"
          class="mt-6 space-y-6"
        >
          <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
            <.input field={@form[:title]} type="text" label="Title" />
            <.input field={@form[:type]} type="text" label="Type" />
            <.input
              field={@form[:ring]}
              type="select"
              label="Ring"
              options={Enum.map(Config.rings(), &{&1.title, &1.id})}
            />
            <.input
              field={@form[:quadrant]}
              type="select"
              label="Quadrant"
              options={Enum.map(Config.quadrants(), &{&1.title, &1.id})}
            />
            <.input
              field={@form[:status]}
              type="select"
              label="Status"
              options={Enum.map(Config.statuses(), &{&1.title, &1.id})}
            />
            <.input field={@form[:stale_after]} type="date" label="Stale after" />
            <.input field={@form[:tags]} type="text" label="Tags (comma-separated)" />
            <.input
              field={@form[:related]}
              type="text"
              label="Related items (comma-separated ids)"
            />
            <.input field={@form[:sources]} type="text" label="Sources (comma-separated URLs)" />
            <.input field={@form[:featured]} type="checkbox" label="Featured" />
          </div>

          <div>
            <div
              id="markdown-toolbar"
              phx-hook=".MarkdownToolbar"
              data-target={@form[:body].id}
              class="flex gap-1 rounded-t-md border border-b-0 border-base-300 bg-base-200 p-1"
            >
              <button type="button" data-md-action="bold" class="btn btn-xs font-bold">B</button>
              <button type="button" data-md-action="italic" class="btn btn-xs italic">i</button>
              <button type="button" data-md-action="link" class="btn btn-xs">Link</button>
              <button type="button" data-md-action="list" class="btn btn-xs">List</button>
              <button type="button" data-md-action="code" class="btn btn-xs font-mono">
                {"</>"}
              </button>
            </div>

            <div class="grid grid-cols-1 gap-4 lg:grid-cols-2">
              <.input
                field={@form[:body]}
                type="textarea"
                label="Body (Markdown)"
                rows="16"
                class="w-full rounded-t-none textarea font-mono text-sm"
              />
              <div class="radar-content rounded-md border border-base-300 p-4">
                {Phoenix.HTML.raw(@preview_html)}
              </div>
            </div>
          </div>

          <div class="flex gap-2">
            <.button type="submit" variant="primary">Save</.button>
            <.button navigate={~p"/radar/#{@item.id}"}>Cancel</.button>
          </div>
        </.form>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".MarkdownToolbar">
        export default {
          mounted() {
            const textarea = document.getElementById(this.el.dataset.target)
            const wrap = {bold: "**", italic: "_", code: "`"}

            this.el.addEventListener("click", e => {
              const button = e.target.closest("[data-md-action]")
              if (!button) return
              const action = button.dataset.mdAction

              const start = textarea.selectionStart
              const end = textarea.selectionEnd
              const selected = textarea.value.slice(start, end) || "text"
              let replacement = selected

              if (wrap[action]) {
                replacement = `${wrap[action]}${selected}${wrap[action]}`
              } else if (action === "link") {
                replacement = `[${selected}](url)`
              } else if (action === "list") {
                replacement = selected.split("\n").map(line => `- ${line}`).join("\n")
              }

              textarea.setRangeText(replacement, start, end, "end")
              textarea.dispatchEvent(new Event("input", {bubbles: true}))
              textarea.focus()
            })
          }
        }
      </script>
    </Layouts.app>
    """
  end
end
