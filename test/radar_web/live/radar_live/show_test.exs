defmodule RadarWeb.RadarLive.ShowTest do
  use RadarWeb.ConnCase

  test "renders a known item's title, body, flag, and history", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/radar/alpha")

    assert html =~ "Alpha"
    assert html =~ "Alpha body, release two"
    assert has_element?(view, "#radar-item-detail")
    assert html =~ "Changed"
    assert html =~ "2024-01-01"
  end

  test "an item with no history renders without a history section", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/radar/beta")

    refute html =~ "History"
  end

  test "redirects to the radar index with a flash for an unknown id", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: to, flash: flash}}} =
             live(conn, ~p"/radar/does-not-exist")

    assert to == ~p"/radar"
    assert flash["error"] =~ "couldn't be found"
  end
end
