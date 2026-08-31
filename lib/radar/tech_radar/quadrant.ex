defmodule Radar.TechRadar.Quadrant do
  @moduledoc "A quadrant of the technology radar (e.g. Tools, Platforms)."

  @enforce_keys [:id, :title, :description, :color]
  defstruct [:id, :title, :description, :color]

  @type t :: %__MODULE__{
          id: atom(),
          title: String.t(),
          description: String.t(),
          color: String.t()
        }
end
