defmodule Radar.TechRadar.Ring do
  @moduledoc "A ring of the technology radar (e.g. Adopt, Trial, Assess, Hold)."

  @enforce_keys [:id, :title, :description, :color, :radius, :stroke_width]
  defstruct [:id, :title, :description, :color, :radius, :stroke_width]

  @type t :: %__MODULE__{
          id: atom(),
          title: String.t(),
          description: String.t(),
          color: String.t(),
          radius: float(),
          stroke_width: pos_integer()
        }
end
