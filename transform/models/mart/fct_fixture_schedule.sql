with fixtures as (
    select * from {{ ref('stg_fixtures') }}
),

teams as (
    select * from {{ ref('stg_teams') }}
),

upcoming as (
    select * from fixtures
    where finished = false
      and kickoff_time > current_timestamp()
),

home_fixtures as (
    select
        gameweek,
        fixture_id,
        kickoff_time,
        team_h                                                          as team_id,
        team_a                                                          as opponent_id,
        team_h_difficulty                                               as difficulty,
        'Home'                                                          as venue
    from upcoming
),

away_fixtures as (
    select
        gameweek,
        fixture_id,
        kickoff_time,
        team_a                                                          as team_id,
        team_h                                                          as opponent_id,
        team_a_difficulty                                               as difficulty,
        'Away'                                                          as venue
    from upcoming
),

all_fixtures as (
    select * from home_fixtures
    union all
    select * from away_fixtures
)

select
    f.gameweek,
    f.fixture_id,
    f.kickoff_time,
    f.team_id,
    t.name                                                              as team_name,
    t.short_name                                                        as team_short_name,
    opp.name                                                            as opponent_name,
    opp.short_name                                                      as opponent_short_name,
    f.venue,
    f.difficulty,
    case f.difficulty
        when 1 then 'Very Easy'
        when 2 then 'Easy'
        when 3 then 'Medium'
        when 4 then 'Hard'
        when 5 then 'Very Hard'
    end                                                                 as difficulty_label,
    t.strength_overall_home,
    t.strength_overall_away,
    opp.strength_defence_home,
    opp.strength_defence_away

from all_fixtures f
left join teams t on f.team_id = t.team_id
left join teams opp on f.opponent_id = opp.team_id

order by f.kickoff_time, t.name
