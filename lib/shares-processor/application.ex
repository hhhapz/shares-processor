defmodule SP.CLI do
  import SP.Processor

  def main([]) do
    main(["data"])
  end

  def main([folder]) do
    ms =
      measure(fn ->
        {list, aggregate, _, dates} = generate(folder)

        write_csv("output.csv", list, dates)
        write_csv("output-aggregate.csv", aggregate, dates)
      end)

    IO.puts("Completed in #{ms}ms.")
  end

  def measure(function) do
    function
    |> :timer.tc()
    |> elem(0)
    |> Kernel./(1_000_000)
  end
end
