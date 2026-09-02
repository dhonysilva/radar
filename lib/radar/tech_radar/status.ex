defmodule Radar.TechRadar.Status do
  @moduledoc "The lifecycle status of an item's write-up: draft, stable, or deprecated."

  @enforce_keys [:id, :title, :color, :description]
  defstruct [:id, :title, :color, :description]

  @type t :: %__MODULE__{
          id: :draft | :stable | :deprecated,
          title: String.t(),
          color: String.t(),
          description: String.t()
        }
end
