defmodule SP.Processor do
  defmodule Row do
    defstruct name: "", other_alias: "", sid: "", stocks: %{}
  end

  @csv_opts [strip_fields: true, headers: true, validate_row_length: false]

  @jumlah "jumlah"
  @name "nama investor"
  @sid "nomor sid"

  def input(folder) do
    files =
      File.ls!(folder)
      |> Enum.map(fn x -> {Path.expand("./#{folder}/#{x}"), x} end)
      |> Enum.sort()
      |> Enum.map(fn {x, name} -> {File.stream!(x), name} end)
      |> Enum.map(fn {x, name} -> {x, name |> String.split(~r/[ \.]/) |> List.first()} end)
      |> Enum.map(fn {x, name} -> {CSV.decode!(x, @csv_opts), name} end)

    {names, _} =
      files
      |> Enum.find(nil, fn {_, name} -> name == "names" end)

    shares =
      files
      |> Enum.filter(fn {_, name} -> name != "names" end)
      |> Enum.sort()

    dates = shares |> Enum.map(&elem(&1, 1))

    {names, shares, dates}
  end

  def format_entry(row) do
    Enum.map(row, fn {k, v} -> {String.downcase(k), String.upcase(v)} end)
    |> Map.new()
  end

  def parse_names(names) do
    names
    |> Enum.map(&format_entry/1)
    |> Enum.map(fn x -> {x["sid"], x["akr name"]} end)
    |> Map.new()
  end

  def parse_date(data, rows, date) do
    IO.puts("Processing #{date}")

    new =
      rows
      |> Enum.map(&format_entry/1)
      |> Enum.map(fn x ->
        {jumlah, _} = x[@jumlah] |> String.replace(",", "") |> Integer.parse()
        Map.replace!(x, @jumlah, jumlah)
      end)
      |> Enum.group_by(fn x -> x[@sid] end)
      |> Enum.map(&elem(&1, 1))
      |> Enum.map(&Enum.reduce(&1, fn x, y -> Map.put(x, @jumlah, x[@jumlah] + y[@jumlah]) end))
      |> Enum.map(fn x -> {x, Map.get(data, x[@sid], %Row{name: x[@name], sid: x[@sid]})} end)
      |> Enum.map(fn {x, row} ->
        {row.sid,
         %{row | stocks: Map.put(row.stocks, date, Map.get(row.stocks, date, 0) + x[@jumlah])}}
      end)
      |> Map.new()

    Map.merge(data, new)
  end

  def generate(folder) do
    {names, data, dates} = input(folder)
    aliases = parse_names(names)

    zeroes = Enum.reduce(dates, %{}, fn date, map -> Map.put(map, date, 0) end)

    unfiltered =
      data
      |> Enum.reduce(%{}, fn {rows, date}, data -> parse_date(data, rows, date) end)
      |> Enum.map(fn {_, row} -> %{row | other_alias: Map.get(aliases, row.sid, "")} end)
      |> Enum.map(fn row ->
        %{row | stocks: Map.merge(zeroes, row.stocks)}
      end)

    IO.puts("Producing output map...")

    sidList =
      unfiltered
      |> Enum.filter(fn x -> Enum.any?(x.stocks, fn {_, jumlah} -> jumlah >= 500_000 end) end)

    IO.puts("Producing aggregate map...")

    aggregate =
      unfiltered
      |> Enum.group_by(fn x ->
        if x.other_alias == "", do: x.sid, else: x.other_alias
      end)
      |> Enum.map(fn {_, x} -> x end)
      |> Enum.map(
        &Enum.reduce(&1, fn x, y ->
          stocks = Map.merge(x.stocks, y.stocks, fn _k, v1, v2 -> v1 + v2 end)
          Map.put(x, :stocks, stocks)
        end)
      )
      |> Enum.filter(fn x ->
        Enum.any?(x.stocks, fn {_, jumlah} -> jumlah >= 500_000 end) || x.other_alias != ""
      end)

    {sidList, aggregate, unfiltered, dates}
  end

  def headers(dates) do
    ["Name", "Alias Name", "SID"] ++ (dates |> Enum.sort())
  end

  def write_csv(file_name, data, dates) do
    output = File.open!(file_name, [:write, :utf8])

    ([headers(dates)] ++
       (data
        |> Enum.sort_by(fn x -> x.stocks end, :desc)
        |> Enum.map(fn x ->
          [x.name, x.other_alias, x.sid] ++
            Enum.map(x.stocks, fn {_, v} -> Integer.to_string(v) end)
        end)))
    |> CSV.encode()
    |> Enum.each(&IO.write(output, &1))
  end
end
