defmodule Radar.TechRadar.ItemBuilder do
  @moduledoc """
  Merges the flat list of per-file `Radar.TechRadar.Release`s into one
  `Radar.TechRadar.Item` per slug: the latest release becomes the item's
  current attributes, earlier releases become its `:history`, and a `:flag`
  is derived (`:new` if it first appeared in the overall latest release,
  `:changed` if its ring differs from the immediately preceding release).
  """

  alias Radar.TechRadar.{Item, Release}

  @spec from_releases([Release.t()]) :: [Item.t()]
  def from_releases(releases) do
    latest_release_date = releases |> Enum.map(& &1.date) |> Enum.max(Date, fn -> nil end)

    releases
    |> Enum.group_by(& &1.id)
    |> Enum.map(fn {_id, item_releases} -> build_item(item_releases, latest_release_date) end)
    |> Enum.sort_by(& &1.id)
  end

  defp build_item(item_releases, latest_release_date) do
    [current | earlier] = Enum.sort_by(item_releases, & &1.date, {:desc, Date})
    previous = List.first(earlier)

    history =
      earlier
      |> Enum.sort_by(& &1.date, Date)
      |> Enum.map(&%{release_date: &1.date, ring: &1.ring})

    flag =
      cond do
        earlier == [] and Date.compare(current.date, latest_release_date) == :eq -> :new
        previous && previous.ring != current.ring -> :changed
        true -> nil
      end

    %Item{
      id: current.id,
      title: current.title,
      ring: current.ring,
      quadrant: current.quadrant,
      tags: current.tags,
      featured: current.featured,
      related: current.related,
      body_html: current.body_html,
      release_date: current.date,
      history: history,
      flag: flag
    }
  end
end
