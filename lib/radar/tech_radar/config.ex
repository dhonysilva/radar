defmodule Radar.TechRadar.Config do
  @moduledoc """
  Static configuration for the technology radar: quadrants, rings, and flags.

  This mirrors the reference AOE Technology Radar's `config.json`, but as
  plain compile-time Elixir data since this project has no admin UI —
  edit the lists below directly to change the radar's shape.
  """

  alias Radar.TechRadar.{Flag, Quadrant, Ring, Status}

  @quadrants [
    %Quadrant{
      id: :techniques,
      title: "Techniques",
      description: "Ways of working: architectural patterns, processes, and practices.",
      color: "#5b6ee1"
    },
    %Quadrant{
      id: :tools,
      title: "Tools",
      description: "Software that supports engineering work.",
      color: "#e15b8f"
    },
    %Quadrant{
      id: :platforms,
      title: "Platforms",
      description: "Things we build on top of: databases, cloud services, runtimes.",
      color: "#2fa38c"
    },
    %Quadrant{
      id: :"languages-and-frameworks",
      title: "Languages & Frameworks",
      description: "Programming languages and the frameworks built on top of them.",
      color: "#d98a3d"
    }
  ]

  # Ordered innermost (adopt) to outermost (hold) — ChartLayout relies on this order.
  @rings [
    %Ring{
      id: :adopt,
      title: "Adopt",
      description: "Use this now, in production, with confidence.",
      color: "#4a9c59",
      radius: 0.25,
      stroke_width: 1
    },
    %Ring{
      id: :trial,
      title: "Trial",
      description: "Worth pursuing; proven on real projects, not yet broadly recommended.",
      color: "#37a1c9",
      radius: 0.5,
      stroke_width: 1
    },
    %Ring{
      id: :assess,
      title: "Assess",
      description: "Worth exploring; not yet recommended for production.",
      color: "#e8a33d",
      radius: 0.75,
      stroke_width: 1
    },
    %Ring{
      id: :hold,
      title: "Hold",
      description: "Proceed with caution; better alternatives now exist.",
      color: "#c65146",
      radius: 1.0,
      stroke_width: 1
    }
  ]

  @flags [
    %Flag{
      id: :new,
      color: "#2fa84f",
      title: "New",
      title_short: "N",
      description: "New item in this release"
    },
    %Flag{
      id: :changed,
      color: "#d9822b",
      title: "Changed",
      title_short: "C",
      description: "Moved rings since the last release"
    },
    %Flag{
      id: :default,
      color: "transparent",
      title: "",
      title_short: "",
      description: ""
    }
  ]

  @statuses [
    %Status{
      id: :draft,
      title: "Draft",
      color: "#8a8a8a",
      description: "Still being written or reviewed."
    },
    %Status{
      id: :stable,
      title: "Stable",
      color: "transparent",
      description: "Reviewed and current."
    },
    %Status{
      id: :deprecated,
      title: "Deprecated",
      color: "#8a3a3a",
      description: "This write-up is outdated and pending revision."
    }
  ]

  @quadrant_ids Enum.map(@quadrants, & &1.id)
  @ring_ids Enum.map(@rings, & &1.id)
  @status_ids Enum.map(@statuses, & &1.id)

  @doc "Returns the configured quadrants, in display order."
  @spec quadrants() :: [Quadrant.t()]
  def quadrants, do: @quadrants

  @doc "Returns the configured rings, ordered innermost (adopt) to outermost (hold)."
  @spec rings() :: [Ring.t()]
  def rings, do: @rings

  @doc "Returns the configured flags."
  @spec flags() :: [Flag.t()]
  def flags, do: @flags

  @doc "Returns the configured statuses."
  @spec statuses() :: [Status.t()]
  def statuses, do: @statuses

  @doc "Returns the allowed quadrant ids, as configured."
  @spec quadrant_ids() :: [atom()]
  def quadrant_ids, do: @quadrant_ids

  @doc "Returns the allowed ring ids, as configured."
  @spec ring_ids() :: [atom()]
  def ring_ids, do: @ring_ids

  @doc "Returns the allowed status ids, as configured."
  @spec status_ids() :: [atom()]
  def status_ids, do: @status_ids

  @doc "Fetches a quadrant by id, or returns `nil`."
  @spec quadrant(atom()) :: Quadrant.t() | nil
  def quadrant(id), do: Enum.find(@quadrants, &(&1.id == id))

  @doc "Fetches a ring by id, or returns `nil`."
  @spec ring(atom()) :: Ring.t() | nil
  def ring(id), do: Enum.find(@rings, &(&1.id == id))

  @doc "Fetches a flag by id, or returns `nil`."
  @spec flag(atom()) :: Flag.t() | nil
  def flag(id), do: Enum.find(@flags, &(&1.id == id))

  @doc "Fetches a status by id, or returns `nil`."
  @spec status(atom()) :: Status.t() | nil
  def status(id), do: Enum.find(@statuses, &(&1.id == id))
end
