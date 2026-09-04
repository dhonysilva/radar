defmodule RadarWeb.RadarLive.GraphTest do
  use RadarWeb.ConnCase

  test "renders a node for every item and a line for every edge", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/radar/graph")

    assert html =~ "Radar Graph"
    assert has_element?(view, "#graph-view")
    assert has_element?(view, "#graph-node-alpha")
    assert has_element?(view, "#graph-node-beta")
    assert has_element?(view, "#graph-node-gamma")

    # alpha's latest release relates to beta — exactly one edge in the fixtures.
    assert Regex.scan(~r/<line\b/, html) |> length() == 1
  end

  test "filtering dims non-matching nodes without removing them", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/radar/graph")

    view
    |> form("#graph-filters", filters: %{ring: "adopt"})
    |> render_change()

    html = render(view)

    assert style_for(html, "graph-node-alpha") =~ "opacity: 1"
    assert style_for(html, "graph-node-beta") =~ "opacity: 0.15"
    # still present in the DOM, just dimmed — not removed like the index cards.
    assert has_element?(view, "#graph-node-beta")
  end

  test "the radar index links to the graph page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/radar")

    assert html =~ ~s(href="/radar/graph")
  end

  defp style_for(html, id) do
    [_, style] = Regex.run(~r/id="#{id}"[^>]*style="([^"]*)"/, html)
    style
  end
end
