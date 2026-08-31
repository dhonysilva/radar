defmodule RadarWeb.PageController do
  use RadarWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/radar")
  end
end
