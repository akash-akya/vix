defmodule Vix.LibvipsPrecompiled do
  require Logger

  def run do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    fetch_libvips()
  end

  @vips_version "8.15.3"

  def fetch_libvips do
    version = System.get_env("LIBVIPS_VERSION") || @vips_version
    target = current_target()
    {url, filename} = url(version, target)

    {:ok, path} = download(url, Path.join(priv_dir(), filename))
    :ok = extract(path)

    :ok
  end

  @release_tag "8.15.3-rc3"

  @filename "libvips-<%= version %>-<%= suffix %>.tar.gz"
  @url "https://github.com/akash-akya/sharp-libvips/releases/download/v<%= tag %>/<%= filename %>"

  defp url(version, target) do
    {:ok, suffix} = cast_target(target)

    filename = EEx.eval_string(@filename, version: version, suffix: suffix)
    url = EEx.eval_string(@url, tag: @release_tag, filename: filename)

    {url, filename}
  end

  defp cast_target(%{os: os, arch: arch, abi: abi}) do
    case {arch, os, abi} do
      {"x86_64", "linux", "musl"} ->
        {:ok, "linuxmusl-x64"}

      {"aarch64", "linux", "musl"} ->
        {:ok, "linuxmusl-arm64v8"}

      {"x86_64", "linux", "gnu"} ->
        {:ok, "linux-x64"}

      {"aarch64", "linux", "gnu"} ->
        {:ok, "linux-arm64v8"}

      {"armv7l", "linux", "gnueabihf"} ->
        {:ok, "linux-armv7"}

      {"x86_64", "apple", "darwin"} ->
        {:ok, "darwin-x64"}

      {"aarch64", "apple", "darwin"} ->
        {:ok, "darwin-arm64v8"}
    end
  end

  defp extract(path) do
    Logger.debug("Extracting to #{path}")
    destination = to_charlist(Path.join(priv_dir(), "precompiled_libvips"))
    _ = File.rmdir(destination)

    :ok = :erl_tar.extract(to_charlist(path), [{:cwd, destination}, :compressed])

    :ok
  end

  def download(url, path) do
    hostname = String.to_charlist(URI.parse(url).host)

    Logger.debug("Fetching #{url}")
    _ = File.rm(path)
    File.mkdir_p!(Path.dirname(path))

    {:ok, :saved_to_file} =
      :httpc.request(
        :get,
        {String.to_charlist(url), []},
        https_opts(hostname),
        stream: String.to_charlist(path)
      )

    {:ok, path}
  end

  defp https_opts(hostname) do
    [
      ssl: [
        verify: :verify_peer,
        cacertfile: String.to_charlist(CAStore.file_path()),
        server_name_indication: hostname,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    ]
  end

  def current_target do
    current_target_from_env = current_target_from_env()

    {:ok, {arch, os, abi}} =
      if current_target_from_env do
        # overwrite current target triplet
        {:ok, current_target_from_env}
      else
        current_target(:os.type())
      end

    %{arch: arch, os: os, abi: abi}
  end

  defp current_target_from_env do
    if target = System.get_env("CC_PRECOMPILER_CURRENT_TARGET") do
      [arch, os, abi] = String.split(target, "-")
      {arch, os, abi}
    end
  end

  defp current_target({:win32, _}) do
    processor_architecture =
      String.downcase(String.trim(System.get_env("PROCESSOR_ARCHITECTURE")))

    compiler =
      case :erlang.system_info(:c_compiler_used) do
        {:msc, _} -> "msvc"
        {:gnuc, _} -> "gnu"
        {other, _} -> Atom.to_string(other)
      end

    # https://docs.microsoft.com/en-gb/windows/win32/winprog64/wow64-implementation-details?redirectedfrom=MSDN
    case processor_architecture do
      "amd64" ->
        {:ok, {"x86_64", "windows", compiler}}

      "ia64" ->
        {:ok, {"ia64", "windows", compiler}}

      "arm64" ->
        {:ok, {"aarch64", "windows", compiler}}

      "x86" ->
        {:ok, {"x86", "windows", compiler}}
    end
  end

  defp current_target({:unix, _}) do
    # get current target triplet from `:erlang.system_info/1`
    system_architecture = to_string(:erlang.system_info(:system_architecture))
    current = String.split(system_architecture, "-", trim: true)

    case length(current) do
      4 ->
        {:ok, {Enum.at(current, 0), Enum.at(current, 2), Enum.at(current, 3)}}

      3 ->
        case :os.type() do
          {:unix, :darwin} ->
            # could be something like aarch64-apple-darwin21.0.0
            # but we don't really need the last 21.0.0 part
            if String.match?(Enum.at(current, 2), ~r/^darwin.*/) do
              {:ok, {Enum.at(current, 0), Enum.at(current, 1), "darwin"}}
            else
              {:ok, List.to_tuple(current)}
            end

          _ ->
            {:ok, List.to_tuple(current)}
        end

      _ ->
        {:error, "cannot decide current target"}
    end
  end

  defp priv_dir do
    Path.join(Mix.Project.app_path(), "priv")
  end
end

Vix.LibvipsPrecompiled.run()
