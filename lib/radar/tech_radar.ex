defmodule Radar.TechRadar do
  @moduledoc """
  Public API for the technology radar: items (compiled from markdown files
  under `priv/radar/releases/` at build time), the quadrant/ring/flag
  configuration, and the about page.
  """

  alias Radar.TechRadar.{About, Config, Item, ItemBuilder, Releases}

  @items ItemBuilder.from_releases(Releases.all())

  known_ids = MapSet.new(@items, & &1.id)

  for item <- @items,
      related_id <- item.related,
      not MapSet.member?(known_ids, related_id) do
    raise "item #{inspect(item.id)} has a related id #{inspect(related_id)} " <>
            "that does not match any known item id"
  end

  @doc "Returns every radar item, sorted by title."
  @spec list_items() :: [Item.t()]
  def list_items, do: Enum.sort_by(@items, & &1.title)

  @doc "Fetches a single item by id."
  @spec get_item(String.t()) :: {:ok, Item.t()} | :error
  def get_item(id) do
    case Enum.find(@items, &(&1.id == id)) do
      nil -> :error
      item -> {:ok, item}
    end
  end

  @doc "Returns the configured quadrants."
  defdelegate list_quadrants(), to: Config, as: :quadrants

  @doc "Returns the configured rings, innermost (adopt) to outermost (hold)."
  defdelegate list_rings(), to: Config, as: :rings

  @doc "Returns the configured flags."
  defdelegate list_flags(), to: Config, as: :flags

  @doc "Returns the configured statuses."
  defdelegate list_statuses(), to: Config, as: :statuses

  @doc """
  Whether `item` is stale — its `stale_after` date has arrived or passed,
  relative to `today` (defaults to the real current date).
  """
  @spec stale?(Item.t(), Date.t()) :: boolean()
  def stale?(item, today \\ Date.utc_today())
  def stale?(%{stale_after: nil}, _today), do: false
  def stale?(%{stale_after: stale_after}, today), do: Date.compare(today, stale_after) != :lt

  @doc "Returns every tag used by at least one item, sorted alphabetically."
  @spec list_tags() :: [String.t()]
  def list_tags do
    @items |> Enum.flat_map(& &1.tags) |> Enum.uniq() |> Enum.sort()
  end

  @doc """
  Filters `items` by the given criteria (string or atom keys). Any filter
  left blank/absent is ignored. `:quadrant` and `:ring` match an item's
  quadrant/ring id (compared as strings, so URL query-param strings work
  directly); `:tag` matches an exact tag; `:query` matches a
  case-insensitive substring of the title.
  """
  @spec filter_items([Item.t()], map()) :: [Item.t()]
  def filter_items(items, filters) do
    items
    |> filter_by(:quadrant, fetch_filter(filters, :quadrant))
    |> filter_by(:ring, fetch_filter(filters, :ring))
    |> filter_by_tag(fetch_filter(filters, :tag))
    |> filter_by_query(fetch_filter(filters, :query))
  end

  @doc "Returns the about page, pre-rendered to sanitized HTML."
  defdelegate about_html(), to: About, as: :html

  defp fetch_filter(filters, key) do
    (Map.get(filters, key) || Map.get(filters, to_string(key))) |> blank_to_nil()
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp filter_by(items, _field, nil), do: items

  defp filter_by(items, field, value) do
    Enum.filter(items, &(to_string(Map.fetch!(&1, field)) == to_string(value)))
  end

  defp filter_by_tag(items, nil), do: items
  defp filter_by_tag(items, tag), do: Enum.filter(items, &(tag in &1.tags))

  defp filter_by_query(items, nil), do: items

  defp filter_by_query(items, query) do
    downcased_query = String.downcase(query)
    Enum.filter(items, &String.contains?(String.downcase(&1.title), downcased_query))
  end
end
