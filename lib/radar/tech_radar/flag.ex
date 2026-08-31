defmodule Radar.TechRadar.Flag do
  @moduledoc "A badge shown on an item that is new or changed rings since the last release."

  @enforce_keys [:id, :color, :title, :title_short, :description]
  defstruct [:id, :color, :title, :title_short, :description]

  @type t :: %__MODULE__{
          id: :new | :changed | :default,
          color: String.t(),
          title: String.t(),
          title_short: String.t(),
          description: String.t()
        }
end
