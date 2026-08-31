defmodule RadarWeb.PageControllerTest do
  use RadarWeb.ConnCase

  test "GET / redirects to the radar", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/radar"
  end
end
