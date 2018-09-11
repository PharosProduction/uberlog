defmodule Uberlog.File do
  @moduledoc false

  use GenEvent

  @type path      :: String.t
  @type file      :: :file.io_device
  @type inode     :: File.Stat.t
  @type format    :: String.t
  @type level     :: Logger.level
  @type metadata  :: [atom]

  @replacement "�"
  @default_format "$time $metadata[$level] $message\n"

  ##### Public #####

  @spec prune(IO.chardata) :: IO.chardata
  def prune(binary) when is_binary(binary), do: prune_binary(binary, "")
  def prune([h|t]) when h in 0..1114111, do: [h | prune(t)]
  def prune([h|t]), do: [prune(h) | prune(t)]
  def prune([]), do: []
  def prune(_), do: @replacement

  ##### Callbacks #####

  @impl true
  def init({__MODULE__, name}), do: {:ok, configure(name, [])}

  @impl true
  def handle_call({:configure, opts}, %{name: name} = state) do
    {:ok, :ok, configure(name, opts, state)}
  end
  def handle_call(:path, %{path: path} = state) do
    {:ok, {:ok, path}, state}
  end

  @impl true
  def handle_event({level, _gl, {Logger, msg, ts, md}}, %{level: min_level, metadata_filter: metadata_filter} = state) do
    if (is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt) and metadata_matches?(md, metadata_filter) do
      log_event(level, msg, ts, md, state)
    else
      {:ok, state}
    end
  end
  def handle_event(:flush, state), do: {:ok, state}

  ##### Private #####

  defp log_event(_level, _msg, _ts, _md, %{path: nil} = state), do: {:ok, state}
  
  defp log_event(level, msg, ts, md, %{path: path, io_device: nil} = state) when is_binary(path) do
    case open_log(path) do
      {:ok, io_device, inode} -> log_event(level, msg, ts, md, %{state | io_device: io_device, inode: inode})
      _ -> {:ok, state}
    end
  end

  defp log_event(level, msg, ts, md, %{path: path, io_device: io_device, inode: inode, rotate: rotate, file_date: file_date} = state) when is_binary(path) do
    {{:ok, io_device, inode}, new_file_date} = rotate(path, rotate, file_date, ts, io_device, inode)
    if !is_nil(inode) and inode == get_inode(path) do
      output = format_event(level, msg, ts, md, state)

      try do
        IO.write(io_device, output)
        {:ok, %{state | file_date: new_file_date}}
      rescue
        ErlangError ->
          case open_log(path) do
            {:ok, io_device, inode} ->
              IO.write(io_device, prune(output))
              {:ok, %{state | io_device: io_device, inode: inode, file_date: new_file_date}}

            _ -> {:ok, %{state | io_device: nil, inode: nil, file_date: new_file_date}}
          end
      end
    else
      File.close(io_device)
      log_event(level, msg, ts, md, %{state | io_device: nil, inode: nil, file_date: new_file_date})
    end
  end

  defp rotate(path, %{period: :date, keep: keep}, file_date, ts, io_device, inode) when is_integer(keep) and keep > 0 do
    rootname = Path.rootname(path)
    extension = Path.extname(path)
    files = Path.wildcard("#{rootname}*#{extension}")

    if Enum.count(files) > keep do
      files
      |> Enum.sort()
      |> Enum.slice(keep..Enum.count(files))
      |> Enum.map(&File.rm/1)
    end

    file_date = if !file_date do
      case File.stat(path) do
        {:ok, %{mtime: {file_date, _}}} -> Date.from_erl!(file_date)
        _ -> nil
      end
    else
      file_date
    end

    {ts_date, _} = ts
    ts_date = Date.from_erl!(ts_date)

    if file_date && ts_date != file_date do
      File.rename(path, "#{rootname}_#{file_date}#{extension}")
      {open_log(path), ts_date}
    else
      {{:ok, io_device, inode}, ts_date}
    end
  end

  defp rotate( _, nil, _, _, io_device, inode), do: {{:ok, io_device, inode}, nil}

  defp open_log(path) do
    case (path |> Path.dirname |> File.mkdir_p) do
      :ok ->
        case File.open(path, [:append, :utf8]) do
          {:ok, io_device} -> {:ok, io_device, get_inode(path)}
          other -> other
        end

      other -> other
    end
  end

  defp format_event(level, msg, ts, md, %{format: format, metadata: keys}) do
    Logger.Formatter.format(format, level, msg, ts, take_metadata(md, keys))
  end

  @spec metadata_matches?(Keyword.t, nil|Keyword.t) :: true|false
  def metadata_matches?(_md, nil), do: true
  def metadata_matches?(_md, []), do: true # all of the filter keys are present
  def metadata_matches?(md, [{key, val}|rest]) do
    case Keyword.fetch(md, key) do
      {:ok, ^val} -> metadata_matches?(md, rest)
      _ -> false #fail on first mismatch
    end
  end

  defp take_metadata(metadata, keys) do
    metadatas = Enum.reduce(keys, [], fn key, acc ->
      case Keyword.fetch(metadata, key) do
        {:ok, val} -> [{key, val} | acc]
        :error     -> acc
      end
    end)

    Enum.reverse(metadatas)
  end

  defp get_inode(path) do
    case File.stat(path) do
      {:ok, %File.Stat{inode: inode}} -> inode
      {:error, _} -> nil
    end
  end

  defp configure(name, opts) do
    state = %{
      name: nil,
      path: nil,
      io_device: nil,
      inode: nil,
      format: nil,
      level: nil,
      metadata: nil,
      metadata_filter: nil,
      rotate: nil,
      file_date: nil}
    configure(name, opts, state)
  end

  defp configure(name, opts, state) do
    env = Application.get_env(:logger, name, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, name, opts)

    level           = Keyword.get(opts, :level)
    metadata        = Keyword.get(opts, :metadata, [])
    format_opts     = Keyword.get(opts, :format, @default_format)
    format          = Logger.Formatter.compile(format_opts)
    path            = Keyword.get(opts, :path)
    metadata_filter = Keyword.get(opts, :metadata_filter)
    rotate          = Keyword.get(opts, :rotate)
    
    file_date = case File.stat(path) do
      {:ok, %{mtime: {file_date, _}}} -> Date.from_erl!(file_date)
      _ -> nil
    end

    %{state | name: name,
              path: path,
              format: format,
              level: level,
              metadata: metadata,
              metadata_filter: metadata_filter,
              rotate: rotate,
              file_date: file_date}
  end

  defp prune_binary(<<h::utf8, t::binary>>, acc), do: prune_binary(t, <<acc::binary, h::utf8>>)
  defp prune_binary(<<_, t::binary>>, acc), do: prune_binary(t, <<acc::binary, @replacement>>)
  defp prune_binary(<<>>, acc), do: acc
end