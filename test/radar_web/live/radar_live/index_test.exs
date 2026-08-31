defmodule RadarWeb.RadarLive.IndexTest do
  use RadarWeb.ConnCase

  test "renders the chart and every item", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/radar")

    assert html =~ "Technology Radar"
    assert has_element?(view, "#radar-chart")
    assert has_element?(view, "#item-card-alpha")
    assert has_element?(view, "#item-card-beta")
    assert has_element?(view, "#item-card-gamma")
  end

  test "filtering by ring narrows the item list and patches the URL", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/radar")

    view
    |> form("#radar-filters", filters: %{ring: "adopt"})
    |> render_change()

    assert_patch(view, ~p"/radar?ring=adopt")
    assert has_element?(view, "#item-card-alpha")
    refute has_element?(view, "#item-card-beta")
    refute has_element?(view, "#item-card-gamma")
  end

  test "searching by title narrows the item list", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/radar")

    view
    |> form("#radar-filters", filters: %{query: "gam"})
    |> render_change()

    assert has_element?(view, "#item-card-gamma")
    refute has_element?(view, "#item-card-alpha")
    refute has_element?(view, "#item-card-beta")
  end

  test "clearing filters resets to the full list", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/radar?ring=adopt")

    refute has_element?(view, "#item-card-beta")

    view |> element("#radar-clear-filters") |> render_click()

    assert_patch(view, ~p"/radar")
    assert has_element?(view, "#item-card-beta")
  end

  test "a filter with no matches shows the empty state", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/radar?ring=bogus-ring")

    assert has_element?(view, "p", "No items match these filters.")
  end
end
