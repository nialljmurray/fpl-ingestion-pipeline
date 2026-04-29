with players as (

    select * from {{ source('fpl_data', 'players') }}

),

fixtures as (

    select
        *,
        cast(kickoff_time as timestamp) as kickoff_timestamp
    from {{ source('fpl_data', 'fixtures') }}

),

upcoming_fixtures as (

    select * from fixtures
    where finished = false
    and kickoff_timestamp > current_timestamp()

),

team_fixtures as (

    select team_h as team, team_a as opponent, team_h_difficulty as difficulty, event, kickoff_timestamp, 'Home' as home_or_away
    from upcoming_fixtures

    union all

    select team_a as team, team_h as opponent, team_a_difficulty as difficulty, event, kickoff_timestamp, 'Away' as home_or_away
    from upcoming_fixtures

),

next_fixture_per_team as (

    select *,
        row_number() over (partition by team order by kickoff_timestamp asc) as rn
    from team_fixtures

),

top_players as (

    select
        p.first_name,
        p.second_name,
        p.web_name,
        p.team,
        p.element_type,
        case p.element_type
            when 1 then 'Goalkeeper'
            when 2 then 'Defender'
            when 3 then 'Midfielder'
            when 4 then 'Forward'
        end as position,
        cast(p.expected_goals as float64)              as expected_goals,
        cast(p.expected_assists as float64)            as expected_assists,
        cast(p.expected_goal_involvements as float64)  as expected_goal_involvements,
        cast(p.expected_goals_per_90 as float64)       as expected_goals_per_90,
        cast(p.expected_assists_per_90 as float64)     as expected_assists_per_90,
        round(safe_divide(cast(p.expected_goal_involvements as float64), p.minutes) * 90, 2) as xgi_per_90,
        p.total_points,
        round(safe_divide(p.total_points, p.minutes) * 90, 2)      as points_per_90,
        p.minutes,
        round(p.now_cost / 10.0, 1)                                    as price,
        round(safe_divide(p.total_points, p.now_cost / 10.0), 2)      as points_per_million,
        f.event               as next_gameweek,
        f.kickoff_timestamp   as next_kickoff,
        f.home_or_away,
        f.opponent,
        f.difficulty          as fixture_difficulty,
        case f.difficulty
            when 1 then 'Very Easy'
            when 2 then 'Easy'
            when 3 then 'Medium'
            when 4 then 'Hard'
            when 5 then 'Very Hard'
        end as fixture_difficulty_label

    from players p
    left join next_fixture_per_team f
        on p.team = f.team and f.rn = 1

    where p.minutes > 1500

    order by cast(p.expected_goal_involvements as float64) desc

)

select * from top_players 
order by (points_per_million + points_per_90 + xgi_per_90) desc