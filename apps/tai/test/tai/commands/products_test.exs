defmodule Tai.Commands.ProductsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Tai.TestSupport.Mock

  setup do
    on_exit(fn ->
      Application.stop(:tai)
    end)

    {:ok, _} = Application.ensure_all_started(:tai)
    :ok
  end

  test "show products and their trade restrictions for configured exchanges" do
    mock_product(%Tai.Venues.Product{
      venue_id: :test_exchange_a,
      symbol: :btc_usd,
      venue_symbol: "BTC_USD",
      status: :trading,
      type: :spot,
      maker_fee: Decimal.new("0.001"),
      taker_fee: Decimal.new("0.002"),
      min_price: Decimal.new("0.00001000"),
      max_price: Decimal.new("100000.00000000"),
      price_increment: Decimal.new("0.00000100"),
      min_size: Decimal.new("0.00100000"),
      max_size: Decimal.new("100000.00000000"),
      size_increment: Decimal.new("0.00100000"),
      min_notional: Decimal.new("0.01000000")
    })

    mock_product(%Tai.Venues.Product{
      venue_id: :test_exchange_b,
      symbol: :eth_usd,
      venue_symbol: "ETH_USD",
      status: :trading,
      type: :spot,
      min_price: Decimal.new("0.00001000"),
      max_price: Decimal.new("100000.00000000"),
      price_increment: Decimal.new("0.00000100"),
      min_size: Decimal.new("0.00100000"),
      max_size: nil,
      size_increment: Decimal.new("0.00100000"),
      min_notional: Decimal.new("0.01000000")
    })

    assert capture_io(&Tai.CommandsHelper.products/0) == """
           +-----------------+---------+--------------+---------+------+-----------+-----------+-----------------+----------------+-----------+-----------+----------+----------+--------------+
           |           Venue |  Symbol | Venue Symbol |  Status | Type | Maker Fee | Taker Fee | Price Increment | Size Increment | Min Price | Max Price | Min Size | Max Size | Min Notional |
           +-----------------+---------+--------------+---------+------+-----------+-----------+-----------------+----------------+-----------+-----------+----------+----------+--------------+
           | test_exchange_a | btc_usd |      BTC_USD | trading | spot |      0.1% |      0.2% |        0.000001 |          0.001 |   0.00001 |    100000 |    0.001 |   100000 |         0.01 |
           | test_exchange_b | eth_usd |      ETH_USD | trading | spot |           |           |        0.000001 |          0.001 |   0.00001 |    100000 |    0.001 |          |         0.01 |
           +-----------------+---------+--------------+---------+------+-----------+-----------+-----------------+----------------+-----------+-----------+----------+----------+--------------+\n
           """
  end

  test "shows an empty table when there are no products" do
    assert capture_io(&Tai.CommandsHelper.products/0) == """
           +-------+--------+--------------+--------+------+-----------+-----------+-----------------+----------------+-----------+-----------+----------+----------+--------------+
           | Venue | Symbol | Venue Symbol | Status | Type | Maker Fee | Taker Fee | Price Increment | Size Increment | Min Price | Max Price | Min Size | Max Size | Min Notional |
           +-------+--------+--------------+--------+------+-----------+-----------+-----------------+----------------+-----------+-----------+----------+----------+--------------+
           |     - |      - |            - |      - |    - |         - |         - |               - |              - |         - |         - |        - |        - |            - |
           +-------+--------+--------------+--------+------+-----------+-----------+-----------------+----------------+-----------+-----------+----------+----------+--------------+\n
           """
  end
end
