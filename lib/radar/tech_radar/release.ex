defmodule Radar.TechRadar.Release do
  @moduledoc """
  One published version of one radar item — one file under
  `priv/radar/releases/<date>/<slug>.md`. Built by `NimblePublisher` via
  `Radar.TechRadar.Releases`.

  Multiple releases sharing the same `id` (the file's slug, reused across
  release folders) are merged into a single `Radar.TechRadar.Item` by
  `Radar.TechRadar.ItemBuilder`.
  """

  alias Radar.TechRadar.Config

  @enforce_keys [
    :id,
    :date,
    :title,
    :ring,
    :quadrant,
    :tags,
    :featured,
    :related,
    :body_html,
    :path
  ]
  defstruct [:id, :date, :title, :ring, :quadrant, :tags, :featured, :related, :body_html, :path]

  @type t :: %__MODULE__{
          id: String.t(),
          date: Date.t(),
          title: String.t(),
          ring: atom(),
          quadrant: atom(),
          tags: [String.t()],
          featured: boolean(),
          related: [String.t()],
          body_html: String.t(),
          path: String.t()
        }

  @path_regex ~r/releases\/(?<date>\d{4}-\d{2}-\d{2})\/(?<slug>[^\/]+)\.md\z/

  @doc "The `NimblePublisher` build callback."
  def build(path, attrs, body_html) do
    {id, date} = id_and_date_from_path(path)

    %__MODULE__{
      id: id,
      date: date,
      title: Map.fetch!(attrs, :title),
      ring: atom_for!(:ring, Map.fetch!(attrs, :ring), Config.ring_ids(), path),
      quadrant: atom_for!(:quadrant, Map.fetch!(attrs, :quadrant), Config.quadrant_ids(), path),
      tags: Map.get(attrs, :tags, []),
      featured: Map.get(attrs, :featured, true),
      related: Map.get(attrs, :related, []),
      body_html: body_html,
      path: path
    }
  end

  defp id_and_date_from_path(path) do
    case Regex.named_captures(@path_regex, path) do
      %{"date" => date_string, "slug" => slug} ->
        {slug, Date.from_iso8601!(date_string)}

      nil ->
        raise "#{path}: expected a path like priv/radar/releases/<YYYY-MM-DD>/<slug>.md"
    end
  end

  # Looks up the atom whose string form matches `value`, rather than calling
  # `String.to_atom/1` on file content (AGENTS.md forbids atoms from
  # untrusted input) — `allowed_ids` is the fixed, already-existing set of
  # configured ring/quadrant atoms, so no new atoms are ever created here.
  defp atom_for!(field, value, allowed_ids, path) do
    Enum.find(allowed_ids, &(Atom.to_string(&1) == value)) ||
      raise "#{path}: unknown #{field} #{inspect(value)}, expected one of " <>
              inspect(Enum.map(allowed_ids, &Atom.to_string/1))
  end
end
