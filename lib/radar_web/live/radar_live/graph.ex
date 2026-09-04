defmodule RadarWeb.RadarLive.Graph do
  use RadarWeb, :live_view

  alias Radar.TechRadar
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    all_items = TechRadar.list_items()
    quadrants = TechRadar.list_quadrants()
    rings = TechRadar.list_rings()
    graph = TechRadar.graph()

    {:ok,
     socket
     |> assign(:page_title, "Radar Graph")
     |> assign(:all_items, all_items)
     |> assign(:quadrants, quadrants)
     |> assign(:rings, rings)
     |> assign(:tags, TechRadar.list_tags())
     |> assign(:ring_by_id, Map.new(rings, &{&1.id, &1}))
     |> assign(:geometry, TechRadar.graph_geometry())
     |> assign(:positions, graph.positions)
     |> assign(:edges, graph.edges)
     |> assign(:degree, degree_map(graph.edges))}
  end

  defp degree_map(edges) do
    Enum.reduce(edges, %{}, fn {id_a, id_b}, acc ->
      acc
      |> Map.update(id_a, 1, &(&1 + 1))
      |> Map.update(id_b, 1, &(&1 + 1))
    end)
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = %{
      "quadrant" => params["quadrant"] || "",
      "ring" => params["ring"] || "",
      "tag" => params["tag"] || "",
      "query" => params["q"] || ""
    }

    filtered_items = TechRadar.filter_items(socket.assigns.all_items, filters)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filter_form, to_form(filters, as: :filters))
     |> assign(:visible_ids, MapSet.new(filtered_items, & &1.id))}
  end

  @impl true
  def handle_event("filter", %{"filters" => params}, socket) do
    query = params |> Map.take(["quadrant", "ring", "tag", "query"]) |> to_query_params()
    {:noreply, push_patch(socket, to: ~p"/radar/graph?#{query}")}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/radar/graph")}
  end

  defp to_query_params(params) do
    for {key, value} <- params, value not in [nil, ""], into: %{} do
      {if(key == "query", do: "q", else: key), value}
    end
  end

  attr :items, :list, required: true
  attr :positions, :map, required: true
  attr :edges, :list, required: true
  attr :geometry, :map, required: true
  attr :ring_by_id, :map, required: true
  attr :visible_ids, :map, required: true
  attr :degree, :map, required: true

  def graph_view(assigns) do
    edge_lines =
      Enum.map(assigns.edges, fn {id_a, id_b} ->
        %{a: assigns.positions[id_a], b: assigns.positions[id_b]}
      end)

    assigns = assign(assigns, :edge_lines, edge_lines)

    ~H"""
    <svg
      id="graph-view"
      phx-hook=".GraphPanZoom"
      viewBox={"0 0 #{@geometry.width} #{@geometry.height}"}
      class="mx-auto w-full max-w-4xl touch-none rounded-md border border-base-300 select-none"
      role="img"
      aria-label="Radar items relationship graph"
    >
      <line
        :for={edge <- @edge_lines}
        x1={edge.a.x}
        y1={edge.a.y}
        x2={edge.b.x}
        y2={edge.b.y}
        class="stroke-base-content/20"
      />

      <g :for={item <- @items} :if={point = @positions[item.id]} class="group">
        <circle
          id={"graph-node-#{item.id}"}
          cx={point.x}
          cy={point.y}
          r={5 + min(Map.get(@degree, item.id, 0), 8)}
          style={"fill: #{@ring_by_id[item.ring].color}; opacity: #{if MapSet.member?(@visible_ids, item.id), do: "1", else: "0.15"}; cursor: pointer;"}
          phx-click={JS.navigate(~p"/radar/#{item.id}")}
        >
          <title>{item.title}</title>
        </circle>
        <text
          x={point.x + 10}
          y={point.y + 4}
          class="pointer-events-none fill-base-content text-[10px] opacity-0 transition-opacity duration-150 select-none group-hover:opacity-100"
        >
          {item.title}
        </text>
      </g>
    </svg>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".GraphPanZoom">
      export default {
        mounted() {
          const svg = this.el
          const [baseX, baseY, baseW, baseH] = svg.getAttribute("viewBox").split(" ").map(Number)
          let [x, y, w, h] = [baseX, baseY, baseW, baseH]
          let dragging = false
          let last = {x: 0, y: 0}

          const applyViewBox = () => svg.setAttribute("viewBox", `${x} ${y} ${w} ${h}`)

          this.onWheel = e => {
            e.preventDefault()
            const factor = e.deltaY > 0 ? 1.1 : 0.9
            const newW = Math.min(Math.max(w * factor, baseW * 0.2), baseW * 3)
            const newH = Math.min(Math.max(h * factor, baseH * 0.2), baseH * 3)
            const rect = svg.getBoundingClientRect()
            const mx = x + (e.clientX - rect.left) / rect.width * w
            const my = y + (e.clientY - rect.top) / rect.height * h
            x = mx - (mx - x) * (newW / w)
            y = my - (my - y) * (newH / h)
            w = newW
            h = newH
            applyViewBox()
          }

          this.onMouseDown = e => {
            dragging = true
            last = {x: e.clientX, y: e.clientY}
          }

          this.onMouseMove = e => {
            if (!dragging) return
            const rect = svg.getBoundingClientRect()
            x -= (e.clientX - last.x) / rect.width * w
            y -= (e.clientY - last.y) / rect.height * h
            last = {x: e.clientX, y: e.clientY}
            applyViewBox()
          }

          this.onMouseUp = () => { dragging = false }

          svg.addEventListener("wheel", this.onWheel, {passive: false})
          svg.addEventListener("mousedown", this.onMouseDown)
          window.addEventListener("mousemove", this.onMouseMove)
          window.addEventListener("mouseup", this.onMouseUp)
        },
        destroyed() {
          window.removeEventListener("mousemove", this.onMouseMove)
          window.removeEventListener("mouseup", this.onMouseUp)
        }
      }
    </script>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Radar Graph
        <:subtitle>How radar items relate to each other. Click a node to open it.</:subtitle>
        <:actions>
          <.button navigate={~p"/radar"}>Back to radar</.button>
        </:actions>
      </.header>

      <.graph_view
        items={@all_items}
        positions={@positions}
        edges={@edges}
        geometry={@geometry}
        ring_by_id={@ring_by_id}
        visible_ids={@visible_ids}
        degree={@degree}
      />

      <div class="mt-4 flex flex-wrap items-center justify-center gap-3 text-xs">
        <span :for={ring <- @rings} class="flex items-center gap-1.5">
          <span class="size-2.5 rounded-full" style={"background-color: #{ring.color}"} />
          {ring.title}
        </span>
      </div>

      <.form
        for={@filter_form}
        id="graph-filters"
        phx-change="filter"
        class="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-4"
      >
        <.input
          field={@filter_form[:query]}
          id="graph-search"
          type="search"
          label="Search"
          placeholder="Search by title"
        />
        <.input
          field={@filter_form[:quadrant]}
          id="graph-filter-quadrant"
          type="select"
          label="Quadrant"
          prompt="All quadrants"
          options={Enum.map(@quadrants, &{&1.title, &1.id})}
        />
        <.input
          field={@filter_form[:ring]}
          id="graph-filter-ring"
          type="select"
          label="Ring"
          prompt="All rings"
          options={Enum.map(@rings, &{&1.title, &1.id})}
        />
        <.input
          field={@filter_form[:tag]}
          id="graph-filter-tag"
          type="select"
          label="Tag"
          prompt="All tags"
          options={@tags}
        />
      </.form>

      <div class="mt-2 flex justify-end">
        <button
          type="button"
          id="graph-clear-filters"
          phx-click="clear_filters"
          class="text-sm underline text-base-content/70 hover:text-base-content"
        >
          Clear filters
        </button>
      </div>
    </Layouts.app>
    """
  end
end
