defmodule RadarWeb.RadarLive.AboutTest do
  use RadarWeb.ConnCase

  test "renders the about page content", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/radar/about")

    assert html =~ "About this radar"
    assert html =~ "About fixture"
  end
end
