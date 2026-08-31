defmodule Radar.TechRadar.Releases do
  @moduledoc false

  use NimblePublisher,
    build: Radar.TechRadar.Release,
    from: Application.compile_env!(:radar, :radar_releases_glob),
    as: :releases,
    parser: Radar.TechRadar.FrontMatterParser,
    html_converter: Radar.TechRadar.HtmlConverter

  @releases Enum.sort_by(@releases, & &1.date, Date)

  @doc "Returns every built release (one entry per file), sorted by date ascending."
  @spec all() :: [Radar.TechRadar.Release.t()]
  def all, do: @releases
end
