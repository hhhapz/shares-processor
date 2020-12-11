defmodule SP.CLI do
  import SP.Processor

  def main do
    main(["data"])
  end

  def main([]) do
    main(["data"])
  end

  def main([folder]) do
    ms =
      measure(fn ->
        {list, aggregate, unfiltered, dates} = generate(folder)

        IO.puts("Writing to file")

        File.mkdir("output")
        write_csv("output/output.csv", list, dates)
        write_csv("output/output-aggregate.csv", aggregate, dates)

        IO.puts("Generating General Statistics")

        frequency =
          unfiltered
          |> Enum.group_by(fn x -> String.slice(x.sid, 0..2) end)
          |> Enum.map(fn {k, v} -> {k, v |> length} end)
          # |> Enum.filter(fn {k, _v} -> k != "" end)
          |> Map.new()

        {:ok, metadata} =
          %{
            "code-frequency" => frequency
          }
          |> YamlEncode.encode()

        File.write("output/metadata.yaml", metadata)
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
