defmodule Radar.TechRadar.HtmlConverter do
  @moduledoc """
  The `:html_converter` for `Radar.TechRadar.Releases`' `NimblePublisher`
  build: renders each item's markdown body to sanitized HTML via MDEx.
  """

  @doc false
  def convert(_path, body, _attrs, _opts) do
    MDEx.to_html!(body,
      extension: [table: true, autolink: true, strikethrough: true],
      sanitize: MDEx.Document.default_sanitize_options()
    )
  end
end
