defmodule RadarWeb.RadarLive.About do
  use RadarWeb, :live_view

  alias Radar.TechRadar

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "About")
     |> assign(:about_html, TechRadar.about_html())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.link navigate={~p"/radar"} class="text-sm text-base-content/70 hover:underline">
        &larr; Back to radar
      </.link>

      <.header>About this radar</.header>

      <div class="radar-content">
        {Phoenix.HTML.raw(@about_html)}
      </div>
    </Layouts.app>
    """
  end
end
