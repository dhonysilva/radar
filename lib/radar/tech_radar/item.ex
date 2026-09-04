defmodule Radar.TechRadar.Item do
  @moduledoc """
  A radar item, merged across all of its releases by
  `Radar.TechRadar.ItemBuilder`. Reflects the latest release's attributes,
  plus the ring it held in each earlier release (`history`) and whether it
  is newly added or changed rings in the latest release (`flag`).
  """

  @enforce_keys [
    :id,
    :title,
    :ring,
    :quadrant,
    :tags,
    :featured,
    :related,
    :type,
    :status,
    :stale_after,
    :sources,
    :body_html,
    :release_date,
    :history,
    :flag,
    :path
  ]
  defstruct [
    :id,
    :title,
    :ring,
    :quadrant,
    :tags,
    :featured,
    :related,
    :type,
    :status,
    :stale_after,
    :sources,
    :body_html,
    :release_date,
    :history,
    :flag,
    :path
  ]

  @type history_entry :: %{release_date: Date.t(), ring: atom()}

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          ring: atom(),
          quadrant: atom(),
          tags: [String.t()],
          featured: boolean(),
          related: [String.t()],
          type: String.t(),
          status: atom(),
          stale_after: Date.t() | nil,
          sources: [String.t()],
          body_html: String.t(),
          release_date: Date.t(),
          history: [history_entry()],
          flag: :new | :changed | nil,
          path: String.t()
        }
end
