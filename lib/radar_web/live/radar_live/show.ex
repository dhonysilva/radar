defmodule RadarWeb.RadarLive.Show do
  use RadarWeb, :live_view

  alias Radar.TechRadar

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case TechRadar.get_item(id) do
      {:ok, item} ->
        quadrant = Enum.find(TechRadar.list_quadrants(), &(&1.id == item.quadrant))
        ring = Enum.find(TechRadar.list_rings(), &(&1.id == item.ring))
        flag = item.flag && Enum.find(TechRadar.list_flags(), &(&1.id == item.flag))

        related_items =
          Enum.flat_map(item.related, fn related_id ->
            case TechRadar.get_item(related_id) do
              {:ok, related_item} -> [related_item]
              :error -> []
            end
          end)

        {:ok,
         socket
         |> assign(:page_title, item.title)
         |> assign(:item, item)
         |> assign(:quadrant, quadrant)
         |> assign(:ring, ring)
         |> assign(:flag, flag)
         |> assign(:related_items, related_items)}

      :error ->
        {:ok,
         socket
         |> put_flash(:error, "That radar item couldn't be found.")
         |> push_navigate(to: ~p"/radar")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="radar-item-detail">
        <.link navigate={~p"/radar"} class="text-sm text-base-content/70 hover:underline">
          &larr; Back to radar
        </.link>

        <.header>
          {@item.title}
          <span
            :if={@flag}
            class="ml-2 inline-block rounded-full px-2 py-0.5 align-middle text-xs font-medium text-white"
            style={"background-color: #{@flag.color}"}
          >
            {@flag.title}
          </span>
          <:subtitle>
            <span
              class="mr-2 inline-block rounded-full px-2 py-0.5 text-xs font-medium text-white"
              style={"background-color: #{@ring.color}"}
            >
              {@ring.title}
            </span>
            <span
              class="inline-block rounded-full px-2 py-0.5 text-xs font-medium text-white"
              style={"background-color: #{@quadrant.color}"}
            >
              {@quadrant.title}
            </span>
          </:subtitle>
        </.header>

        <div class="radar-content">
          {Phoenix.HTML.raw(@item.body_html)}
        </div>

        <div :if={@item.tags != []} class="mt-4 flex flex-wrap gap-1.5 text-xs">
          <span :for={tag <- @item.tags} class="rounded-full bg-base-200 px-2 py-0.5">
            {tag}
          </span>
        </div>

        <div :if={@related_items != []} class="mt-8">
          <h2 class="font-semibold">Related items</h2>
          <ul class="mt-2 flex flex-wrap gap-2 text-sm">
            <li :for={related <- @related_items}>
              <.link
                navigate={~p"/radar/#{related.id}"}
                class="inline-block rounded-full bg-base-200 px-3 py-1 hover:bg-base-300"
              >
                {related.title}
              </.link>
            </li>
          </ul>
        </div>

        <div :if={@item.history != []} class="mt-8">
          <h2 class="font-semibold">History</h2>
          <ul class="mt-2 space-y-1 text-sm text-base-content/70">
            <li :for={entry <- @item.history}>
              {Calendar.strftime(entry.release_date, "%Y-%m-%d")} &mdash; {entry.ring}
            </li>
          </ul>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
