defmodule Examples.PingPong.Advisor do
  @moduledoc """
  Place a passive limit order inside the current quote and immediately flip it
  on the opposing quote side upon fill.

  PLEASE NOTE:
  This advisor is for demonstration purposes only. It does not take into account
  all scenarios required in a production environment. Do not trade this advisor with
  real funds.
  """

  use Tai.Advisor
  import Examples.PingPong.ManageQuoteChange, only: [with_all_quotes: 1, manage_entry_order: 1]

  def handle_inside_quote(_venue_id, _product_symbol, market_quote, _changes, state) do
    {market_quote, state.store}
    |> with_all_quotes()
    |> manage_entry_order()

    {:ok, state.store}
  end
end
