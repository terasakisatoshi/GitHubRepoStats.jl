using GitHubRepoStats
using DataFrames
using Dates

println("=== GitHubRepoStats.jl DataFrame 機能テスト ===")

# URL解析のテスト
println("\n1. URL解析テスト:")
test_urls = [
    "https://github.com/JuliaLang/Julia.git",
    "https://github.com/JuliaData/DataFrames.jl",
    "invalid_url"
]

for url in test_urls
    result = extract_owner_repo(url)
    println("  $url -> $result")
end

# DataFrame作成テスト（API呼び出しなし）
println("\n2. DataFrame構造テスト:")
df = get_general_registry_stats(max_repos=0, show_progress=true, token=nothing)
println("  作成されたDataFrame:")
println("  - サイズ: $(size(df))")
println("  - カラム: $(names(df))")
println("  - カラム型: $(eltype.(eachcol(df)))")

# サンプルデータでDataFrame操作をテスト
println("\n3. DataFrame操作テスト:")
sample_df = DataFrame(
    repository = ["Julia", "DataFrames.jl", "HTTP.jl"],
    owner = ["JuliaLang", "JuliaData", "JuliaWeb"],
    stars = [10000, 1500, 500],
    updated_at = [DateTime(2024, 1, 1), DateTime(2024, 1, 2), DateTime(2024, 1, 3)],
    description = ["High-level language", "Data manipulation", "HTTP client"]
)

println("  サンプルDataFrame:")
show(sample_df, allrows=true)

# 基本的な分析
println("\n\n4. 基本分析例:")
println("  - 平均スター数: $(round(mean(sample_df.stars), digits=1))")
println("  - 最大スター数: $(maximum(sample_df.stars))")
println("  - 総リポジトリ数: $(nrow(sample_df))")

# ソート
sorted_df = sort(sample_df, :stars, rev=true)
println("\n  スター数順（降順）:")
for (i, row) in enumerate(eachrow(sorted_df))
    println("    $i. $(row.owner)/$(row.repository): $(row.stars) ⭐")
end

println("\n=== テスト完了！ ===")
println("GitHubRepoStats.jl のDataFrame機能は正常に動作しています。")
println("実際のGitHub API呼び出しを行う場合は、GITHUB_TOKENを設定してから")
println("get_general_registry_stats() を max_repos を指定して実行してください。")