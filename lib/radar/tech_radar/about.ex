defmodule Radar.TechRadar.About do
  @moduledoc "Compiles the radar's about page from `about.md`."

  @about_path Application.compile_env!(:radar, :radar_about_path)
  @external_resource @about_path

  @html @about_path
        |> File.read!()
        |> MDEx.to_html!(
          extension: [table: true, autolink: true, strikethrough: true],
          sanitize: MDEx.Document.default_sanitize_options()
        )

  @doc "Returns the about page, pre-rendered to sanitized HTML."
  @spec html() :: String.t()
  def html, do: @html
end
