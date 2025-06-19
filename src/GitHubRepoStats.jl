module GitHubRepoStats

using JSON3
using HTTP
using Dates
using DataFrames
using Statistics

# Standard library imports
import TOML
using Random
import Pkg
using CSV
export get_repo_stats, RepoStats, get_general_registry_stats, extract_owner_repo

"""
    RepoStats

A structure to hold GitHub repository statistics.

# Fields
- `name::String`: Repository name
- `owner::String`: Repository owner
- `stars::Int`: Number of stars
- `updated_at::DateTime`: Last updated date
- `description::Union{String, Nothing}`: Repository description
"""
struct RepoStats
    name::String
    owner::String
    stars::Int
    updated_at::DateTime
    description::Union{String, Nothing}
end

"""
    get_repo_stats(owner::String, repo::String; token::Union{String, Nothing} = nothing)

Get GitHub repository statistics including star count and last updated date.

# Arguments
- `owner::String`: Repository owner (username or organization)
- `repo::String`: Repository name
- `token::Union{String, Nothing}`: GitHub personal access token (optional, but recommended for higher rate limits)

# Returns
- `RepoStats`: Structure containing repository statistics

# Example
```julia
# Without token (lower rate limit)
stats = get_repo_stats("JuliaLang", "Julia")

# With token (higher rate limit)
stats = get_repo_stats("JuliaLang", "Julia", token="your_github_token")

println("Repository: \$(stats.owner)/\$(stats.name)")
println("Stars: \$(stats.stars)")
println("Last updated: \$(stats.updated_at)")
println("Description: \$(stats.description)")
```
"""
function get_repo_stats(owner::String, repo::String; token::Union{String, Nothing} = get(ENV, "GITHUB_TOKEN", nothing))
    # GitHub GraphQL API endpoint
    endpoint = "https://api.github.com/graphql"

    # GraphQL query to get repository information
    query = """
    query GetRepoStats(\$owner: String!, \$name: String!) {
        repository(owner: \$owner, name: \$name) {
            name
            owner {
                login
            }
            stargazerCount
            updatedAt
            description
        }
    }
    """

    # Prepare variables
    variables = Dict(
        "owner" => owner,
        "name" => repo
    )

    # Prepare request body
    request_body = Dict(
        "query" => query,
        "variables" => variables
    )

    # Prepare headers
    headers = Dict{String, String}(
        "Content-Type" => "application/json",
        "User-Agent" => "GitHubRepoStats.jl"
    )

    # Add authorization header if token is provided
    if token !== nothing
        headers["Authorization"] = "Bearer $token"
    end

    try
        # Execute the GraphQL request
        response = HTTP.post(endpoint, headers, JSON3.write(request_body))

        # Parse response
        response_data = JSON3.read(response.body)

        # Check for errors
        if haskey(response_data, "errors")
            error("GraphQL query failed: $(response_data["errors"])")
        end

        # Extract data
        repo_data = response_data["data"]["repository"]

        if repo_data === nothing
            error("Repository $owner/$repo not found or not accessible")
        end

        # Parse the updated_at timestamp
        updated_at_str = repo_data["updatedAt"]
        updated_at = DateTime(updated_at_str[1:19])  # Remove timezone info and parse

        # Create and return RepoStats
        return RepoStats(
            repo_data["name"],
            repo_data["owner"]["login"],
            repo_data["stargazerCount"],
            updated_at,
            repo_data["description"]
        )

    catch e
        if isa(e, HTTP.ExceptionRequest.StatusError)
            if e.status == 401
                error("Authentication failed. Please check your GitHub token.")
            elseif e.status == 403
                error("Rate limit exceeded or insufficient permissions. Consider using a GitHub token.")
            else
                error("HTTP error $(e.status): $(e.response)")
            end
        else
            rethrow(e)
        end
    end
end

"""
    format_repo_stats(stats::RepoStats)

Format repository statistics for display.

# Arguments
- `stats::RepoStats`: Repository statistics to format

# Returns
- `String`: Formatted string representation
"""
function format_repo_stats(stats::RepoStats)
    description_text = stats.description !== nothing ? stats.description : "No description"

    return """
    Repository: $(stats.owner)/$(stats.name)
    Stars: $(stats.stars)
    Last Updated: $(stats.updated_at)
    Description: $description_text
    """
end

# Base.show method for pretty printing
Base.show(io::IO, stats::RepoStats) = print(io, format_repo_stats(stats))

"""
    extract_owner_repo(url::String)

Extract owner and repository name from a GitHub URL.

# Arguments
- `url::String`: GitHub repository URL

# Returns
- `Union{Tuple{String, String}, Nothing}`: (owner, repo) tuple or nothing if parsing fails

# Example
```julia
result = extract_owner_repo("https://github.com/JuliaLang/Julia.git")
# result = ("JuliaLang", "Julia")
```
"""
function extract_owner_repo(url::String)
    regex = r"^https?://github\.com/(?P<owner>[^/]+)/(?P<repo>[^/]+?)(?:\.git)?$"

    # マッチング
    m = match(regex, url)
    if m !== nothing
        owner = m["owner"]
        repo = m["repo"]
        return (owner, repo)
    else
        return nothing
    end
end

"""
    get_general_registry_stats(; token::Union{String, Nothing} = get(ENV, "GITHUB_TOKEN", nothing),
                               max_repos::Union{Int, Nothing} = nothing,
                               show_progress::Bool = true,
                               delay::Real = 0.5)

Get GitHub repository statistics for all packages in the Julia General Registry.

# Arguments
- `token::Union{String, Nothing}`: GitHub personal access token (optional)
- `max_repos::Union{Int, Nothing}`: Maximum number of repositories to process (optional, for testing)
- `show_progress::Bool`: Whether to show progress messages
- `delay::Real`: Delay between API calls in seconds (default: 0.5)

# Returns
- `DataFrame`: DataFrame with columns: repository, owner, stars, updated_at, description

# Example
```julia
# Get stats for all General Registry packages (with token)
df = get_general_registry_stats(token="your_github_token")

# Get stats for first 10 packages only
df = get_general_registry_stats(max_repos=10, show_progress=true)

# Access the data
println("Top starred packages:")
sort!(df, :stars, rev=true)
println(first(df, 5))
```
"""
function get_general_registry_stats(; token::Union{String, Nothing} = get(ENV, "GITHUB_TOKEN", nothing),
                                   max_repos::Union{Int, Nothing} = nothing,
                                   show_progress::Bool = true,
                                   delay::Real = 0.5)

    # Get token from environment if not provided
    if token === nothing
        token = get(ENV, "GITHUB_TOKEN", nothing)
    end

    if show_progress
        println("=== Julia General Registry 統計情報取得 ===")
    end

    # General Registry を取得
    general_registry = filter(Pkg.Registry.reachable_registries()) do r
        r.name == "General"
    end |> only
    in_memory_registry = general_registry.in_memory_registry

    if show_progress
        println("General Registry を読み込み中...")
    end

    # 全パッケージのリポジトリURLを取得
    repo_urls = map(collect(values(general_registry.pkgs))) do pkg
        package_toml = TOML.parse(in_memory_registry[joinpath(pkg.path, "Package.toml")])
        return package_toml["repo"], pkg.name
    end

    # URLからowner/repoを抽出
    valid_triplets=[]
    for (url, name) in repo_urls
        e = extract_owner_repo(url)
        isnothing(e) && continue
        push!(valid_triplets, (e..., name))
    end

    # 最大数を制限（指定された場合）
    if max_repos !== nothing
        valid_triplets = valid_triplets[1:min(max_repos, length(valid_triplets))]
    end

    if show_progress
        println("処理対象リポジトリ数: $(length(valid_triplets))")
        println("統計情報を取得中...\n")
    end

    # 結果を格納するベクター
    pkgnames = String[]
    repositories = String[]
    owners = String[]
    stars = Int[]
    updated_ats = DateTime[]
    descriptions = Union{String, Missing}[]

    # 各リポジトリの統計を取得
    for (i, (owner, repo, name)) in enumerate(valid_triplets)
        try
            if show_progress
                print("[$i/$(length(valid_triplets))] $owner/$repo を処理中...")
            end

            # リポジトリ統計を取得
            stats = get_repo_stats(string(owner), string(repo), token=token)

            # 結果をベクターに追加
            push!(pkgnames, name)
            push!(repositories, stats.name)
            push!(owners, stats.owner)
            push!(stars, stats.stars)
            push!(updated_ats, stats.updated_at)
            d = stats.description === nothing ? missing : stats.description
            push!(descriptions, d)

            if show_progress
                println(" ✓ $(stats.stars) stars")
            end

        catch e
            if show_progress
                println(" ❌ エラー: $e")
            end
        end

        # レート制限を考慮した待機
        if i < length(valid_triplets) && delay > 0
            sleep(delay)
        end
    end

    # DataFrameを作成
    df = DataFrame(
        pkg = pkgnames,
        repository = repositories,
        owner = owners,
        stars = stars,
        updated_at = updated_ats,
        description = descriptions
    )

    if show_progress
        println("\n=== 完了 ===")
        println("取得成功: $(nrow(df)) repositories")
        if nrow(df) > 0
            valid_stars = filter(x -> x > 0, df.stars)
            if !isempty(valid_stars)
                println("平均スター数: $(round(mean(valid_stars), digits=1))")
                println("最大スター数: $(maximum(valid_stars))")
            end
        end
    end

    # CSVファイルとして保存
    output_file = "github_repo_stats.csv"
    CSV.write(output_file, df)
    println("結果を $output_file に保存しました")

    return df
end

end # module GitHubRepoStats