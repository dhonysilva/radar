defmodule RadarWeb.RadarLive.Index do
  use RadarWeb, :live_view

  alias Radar.TechRadar
  alias Radar.TechRadar.ChartLayout
  alias Phoenix.LiveView.JS

  @chart_geometry %{
    center: {300, 300},
    chart_radius: 260,
    quadrant_order: Enum.map(TechRadar.list_quadrants(), & &1.id)
  }

  @impl true
  def mount(_params, _session, socket) do
    all_items = TechRadar.list_items()
    quadrants = TechRadar.list_quadrants()
    rings = TechRadar.list_rings()

    {:ok,
     socket
     |> assign(:page_title, "Technology Radar")
     |> assign(:all_items, all_items)
     |> assign(:quadrants, quadrants)
     |> assign(:rings, rings)
     |> assign(:flags, TechRadar.list_flags())
     |> assign(:statuses, TechRadar.list_statuses())
     |> assign(:tags, TechRadar.list_tags())
     |> assign(:quadrant_by_id, Map.new(quadrants, &{&1.id, &1}))
     |> assign(:ring_by_id, Map.new(rings, &{&1.id, &1}))
     |> assign(:chart_geometry, @chart_geometry)
     |> assign(:chart_positions, ChartLayout.layout(all_items, @chart_geometry))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = %{
      "quadrant" => params["quadrant"] || "",
      "ring" => params["ring"] || "",
      "tag" => params["tag"] || "",
      "query" => params["q"] || ""
    }

    filtered_items =
      socket.assigns.all_items
      |> TechRadar.filter_items(filters)
      |> Enum.sort_by(& &1.title)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filter_form, to_form(filters, as: :filters))
     |> assign(:filtered_items, filtered_items)
     |> assign(:visible_ids, MapSet.new(filtered_items, & &1.id))}
  end

  @impl true
  def handle_event("filter", %{"filters" => params}, socket) do
    query = params |> Map.take(["quadrant", "ring", "tag", "query"]) |> to_query_params()
    {:noreply, push_patch(socket, to: ~p"/radar?#{query}")}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/radar")}
  end

  defp to_query_params(params) do
    for {key, value} <- params, value not in [nil, ""], into: %{} do
      {if(key == "query", do: "q", else: key), value}
    end
  end

  defp flag_for(_flags, nil), do: nil
  defp flag_for(flags, flag_id), do: Enum.find(flags, &(&1.id == flag_id))

  attr :item, Radar.TechRadar.Item, required: true
  attr :quadrant_by_id, :map, required: true
  attr :ring_by_id, :map, required: true
  attr :flags, :list, required: true
  attr :statuses, :list, required: true

  def item_card(assigns) do
    ring = assigns.ring_by_id[assigns.item.ring]
    quadrant = assigns.quadrant_by_id[assigns.item.quadrant]
    flag = flag_for(assigns.flags, assigns.item.flag)
    status = Enum.find(assigns.statuses, &(&1.id == assigns.item.status))

    assigns = assign(assigns, ring: ring, quadrant: quadrant, flag: flag, status: status)

    ~H"""
    <.link
      navigate={~p"/radar/#{@item.id}"}
      id={"item-card-#{@item.id}"}
      class="block rounded-lg border border-base-300 p-4 transition hover:border-base-content/30 hover:shadow-sm"
    >
      <div class="flex items-start justify-between gap-2">
        <h3 class="font-semibold">{@item.title}</h3>
        <span
          :if={@flag}
          class="shrink-0 rounded-full px-2 py-0.5 text-xs font-medium text-white"
          style={"background-color: #{@flag.color}"}
        >
          {@flag.title}
        </span>
        <span
          :if={@status.id != :stable}
          class="shrink-0 rounded-full px-2 py-0.5 text-xs font-medium text-white"
          style={"background-color: #{@status.color}"}
        >
          {@status.title}
        </span>
      </div>
      <div class="mt-2 flex flex-wrap gap-1.5 text-xs">
        <span
          class="rounded-full px-2 py-0.5 font-medium text-white"
          style={"background-color: #{@ring.color}"}
        >
          {@ring.title}
        </span>
        <span
          class="rounded-full px-2 py-0.5 font-medium text-white"
          style={"background-color: #{@quadrant.color}"}
        >
          {@quadrant.title}
        </span>
        <span :for={tag <- @item.tags} class="rounded-full bg-base-200 px-2 py-0.5">
          {tag}
        </span>
      </div>
    </.link>
    """
  end

  attr :items, :list, required: true
  attr :positions, :map, required: true
  attr :geometry, :map, required: true
  attr :rings, :list, required: true
  attr :quadrants, :list, required: true
  attr :ring_by_id, :map, required: true
  attr :visible_ids, :map, required: true

  def radar_chart(assigns) do
    {cx, cy} = assigns.geometry.center
    size = assigns.geometry.chart_radius * 2 + 40
    quadrant_labels = quadrant_label_positions(assigns.quadrants, assigns.geometry)

    assigns = assign(assigns, cx: cx, cy: cy, size: size, quadrant_labels: quadrant_labels)

    ~H"""
    <svg
      id="radar-chart"
      viewBox={"0 0 #{@size} #{@size}"}
      class="mx-auto w-full max-w-xl"
      role="img"
      aria-label="Technology radar chart"
    >
      <circle
        :for={ring <- Enum.reverse(@rings)}
        cx={@cx}
        cy={@cy}
        r={ring.radius * @geometry.chart_radius}
        style={"fill: #{ring.color}; opacity: 0.12; stroke: #{ring.color}; stroke-opacity: 0.4"}
      />
      <line
        x1={@cx - @geometry.chart_radius}
        y1={@cy}
        x2={@cx + @geometry.chart_radius}
        y2={@cy}
        class="stroke-base-content/20"
      />
      <line
        x1={@cx}
        y1={@cy - @geometry.chart_radius}
        x2={@cx}
        y2={@cy + @geometry.chart_radius}
        class="stroke-base-content/20"
      />

      <text
        :for={label <- @quadrant_labels}
        x={label.x}
        y={label.y}
        text-anchor="middle"
        class="text-[11px] font-medium fill-base-content/70 uppercase"
      >
        {label.quadrant.title}
      </text>

      <g :for={item <- @items} :if={point = @positions[item.id]}>
        <circle
          id={"blip-#{item.id}"}
          cx={point.x}
          cy={point.y}
          r="7"
          style={"fill: #{@ring_by_id[item.ring].color}; opacity: #{if MapSet.member?(@visible_ids, item.id), do: "1", else: "0.15"}; cursor: pointer;"}
          phx-click={JS.navigate(~p"/radar/#{item.id}")}
        >
          <title>{item.title}</title>
        </circle>
      </g>
    </svg>
    """
  end

  defp quadrant_label_positions(quadrants, geometry) do
    {cx, cy} = geometry.center
    label_radius = geometry.chart_radius + 16

    quadrants
    |> Enum.with_index()
    |> Enum.map(fn {quadrant, index} ->
      angle = (index * 90 + 45) * :math.pi() / 180

      %{
        quadrant: quadrant,
        x: cx + label_radius * :math.cos(angle),
        y: cy + label_radius * :math.sin(angle)
      }
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Technology Radar
        <:subtitle>What we're adopting, trialing, assessing, and holding off on.</:subtitle>
        <:actions>
          <.button navigate={~p"/radar/graph"}>Graph</.button>
          <.button navigate={~p"/radar/about"}>About</.button>
        </:actions>
      </.header>

      <.radar_chart
        items={@all_items}
        positions={@chart_positions}
        geometry={@chart_geometry}
        rings={@rings}
        quadrants={@quadrants}
        ring_by_id={@ring_by_id}
        visible_ids={@visible_ids}
      />

      <div class="mt-6 flex flex-wrap items-center justify-center gap-3 text-xs">
        <span :for={ring <- @rings} class="flex items-center gap-1.5">
          <span class="size-2.5 rounded-full" style={"background-color: #{ring.color}"} />
          {ring.title}
        </span>
      </div>

      <.form
        for={@filter_form}
        id="radar-filters"
        phx-change="filter"
        class="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-4"
      >
        <.input
          field={@filter_form[:query]}
          id="radar-search"
          type="search"
          label="Search"
          placeholder="Search by title"
        />
        <.input
          field={@filter_form[:quadrant]}
          id="radar-filter-quadrant"
          type="select"
          label="Quadrant"
          prompt="All quadrants"
          options={Enum.map(@quadrants, &{&1.title, &1.id})}
        />
        <.input
          field={@filter_form[:ring]}
          id="radar-filter-ring"
          type="select"
          label="Ring"
          prompt="All rings"
          options={Enum.map(@rings, &{&1.title, &1.id})}
        />
        <.input
          field={@filter_form[:tag]}
          id="radar-filter-tag"
          type="select"
          label="Tag"
          prompt="All tags"
          options={@tags}
        />
      </.form>

      <div class="mt-2 flex justify-end">
        <button
          type="button"
          id="radar-clear-filters"
          phx-click="clear_filters"
          class="text-sm underline text-base-content/70 hover:text-base-content"
        >
          Clear filters
        </button>
      </div>

      <div id="item-list" class="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        <.item_card
          :for={item <- @filtered_items}
          item={item}
          quadrant_by_id={@quadrant_by_id}
          ring_by_id={@ring_by_id}
          flags={@flags}
          statuses={@statuses}
        />
      </div>

      <p :if={@filtered_items == []} class="mt-6 text-center text-base-content/60">
        No items match these filters.
      </p>
    </Layouts.app>
    """
  end
end
