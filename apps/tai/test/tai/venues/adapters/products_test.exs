defmodule Tai.Venues.Adapters.ProductsTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup_all do
    on_exit(fn ->
      Application.stop(:tai)
    end)

    {:ok, _} = Application.ensure_all_started(:tai)
    start_supervised!(Tai.TestSupport.Mocks.Server)
    HTTPoison.start()
  end

  @test_adapters Tai.TestSupport.Helpers.test_venue_adapters_products()

  @test_adapters
  |> Enum.map(fn {_, adapter} ->
    @adapter adapter

    test "#{adapter.id} retrieves the product information for the exchange" do
      setup_adapter(@adapter.id)

      use_cassette "venue_adapters/shared/products/#{@adapter.id}/success" do
        assert {:ok, products} = Tai.Venue.products(@adapter)
        assert Enum.count(products) > 0
        assert [%Tai.Venues.Product{} = product | _] = products
        assert product.venue_id == @adapter.id
        assert product.symbol != nil
        assert product.status != nil
        assert %Decimal{} = product.min_size
        assert %Decimal{} = product.size_increment
      end
    end
  end)

  def setup_adapter(:mock) do
    Tai.TestSupport.Mocks.Responses.Products.for_venue(
      :mock,
      [
        %{
          symbol: :btc_usd,
          status: Tai.Venues.ProductStatus.trading(),
          min_notional: Decimal.new("0.0001"),
          min_size: Decimal.new("0.0001"),
          min_price: Decimal.new("0.01"),
          size_increment: Decimal.new("0.001")
        },
        %{
          symbol: :ltc_usd,
          status: Tai.Venues.ProductStatus.trading(),
          min_notional: Decimal.new("0.0001"),
          min_size: Decimal.new("0.0001"),
          min_price: Decimal.new("0.01"),
          size_increment: Decimal.new("0.001")
        }
      ]
    )
  end

  def setup_adapter(_), do: nil
end
