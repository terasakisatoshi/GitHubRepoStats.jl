using Test
using GitHubRepoStats
using Dates
using DataFrames

@testset "GitHubRepoStats.jl" begin
    @testset "RepoStats structure" begin
        # Test RepoStats creation
        stats = RepoStats(
            "TestRepo",
            "TestOwner",
            100,
            DateTime(2023, 1, 1),
            "Test description"
        )

        @test stats.name == "TestRepo"
        @test stats.owner == "TestOwner"
        @test stats.stars == 100
        @test stats.updated_at == DateTime(2023, 1, 1)
        @test stats.description == "Test description"
    end

    @testset "Format repo stats" begin
        stats = RepoStats(
            "TestRepo",
            "TestOwner",
            100,
            DateTime(2023, 1, 1),
            "Test description"
        )

        formatted = GitHubRepoStats.format_repo_stats(stats)
        @test occursin("TestOwner/TestRepo", formatted)
        @test occursin("100", formatted)
        @test occursin("Test description", formatted)
    end

        @testset "URL parsing" begin
        # Test extract_owner_repo function
        result1 = extract_owner_repo("https://github.com/JuliaLang/Julia.git")
        @test result1 == ("JuliaLang", "Julia")

        result2 = extract_owner_repo("https://github.com/JuliaData/DataFrames.jl")
        @test result2 == ("JuliaData", "DataFrames.jl")

        result3 = extract_owner_repo("invalid_url")
        @test result3 === nothing

        result4 = extract_owner_repo("https://github.com/owner/repo.git")
        @test result4 == ("owner", "repo")
    end

        @testset "DataFrame functionality" begin
        # Test that get_general_registry_stats returns a DataFrame
        # Note: This is a mock test that doesn't actually call the API

        # Test the structure without API calls
        @test_nowarn get_general_registry_stats(max_repos=0, show_progress=false, delay=0, token=nothing)

        # Test that the function returns a DataFrame
        df = get_general_registry_stats(max_repos=0, show_progress=false, delay=0, token=nothing)
        @test isa(df, DataFrame)
        @test names(df) == ["pkg", "repository", "owner", "stars", "updated_at", "description"]
    end

    # Note: Real API tests would require a GitHub token and internet connection
    # These tests should be run manually or in CI with proper setup
    @testset "API Integration (Manual)" begin
        # This test requires manual execution with a valid token
        # Uncomment and run manually if needed:

        # token = ENV["GITHUB_TOKEN"]  # Set your token in environment
        # if !isempty(token)
        #     @testset "Real API call" begin
        #         stats = get_repo_stats("JuliaLang", "Julia", token=token)
        #         @test stats.name == "Julia"
        #         @test stats.owner == "JuliaLang"
        #         @test stats.stars > 0
        #         @test isa(stats.updated_at, DateTime)
        #
        #         # Test DataFrame functionality with real data
        #         df = get_general_registry_stats(token=token, max_repos=2, show_progress=false)
        #         @test nrow(df) <= 2
        #         @test names(df) == ["pkg", "repository", "owner", "stars", "updated_at", "description"]
        #     end
        # else
        #     @warn "Skipping real API tests - no GITHUB_TOKEN environment variable set"
        # end
    end
end