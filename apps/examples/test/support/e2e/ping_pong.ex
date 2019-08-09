defmodule ExamplesSupport.E2E.PingPong do
  alias Tai.TestSupport.Mocks
  import Tai.TestSupport.Mock

  @venue :test_exchange_a
  @product_symbol :xbtusd

  def seed_mock_responses(:ping_pong) do
    Mocks.Responses.Products.for_venue(@venue, [%{symbol: @product_symbol}])
  end

  def push_stream_market_data({:ping_pong, :snapshot, venue_id, product_symbol})
      when venue_id == @venue and product_symbol == @product_symbol do
    push_market_data_snapshot(
      %Tai.Markets.Location{
        venue_id: @venue,
        product_symbol: @product_symbol
      },
      %{5500 => 101},
      %{5500.5 => 202}
    )
  end

  def advisor_group_config(:ping_pong) do
    [
      advisor: Examples.PingPong.Advisor,
      factory: Tai.Advisors.Factories.OnePerProduct,
      products: "*"
    ]
  end
end
