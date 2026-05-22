with players as (
    select * from {{ ref('stg_players') }}
),

teams as (
    select * from {{ ref('stg_teams') }}
)

select
    p.player_id,
    p.web_name,
    p.first_name,
    p.second_name,
    p.position,
    t.name                                                              as team_name,
    t.short_name                                                        as team_short_name,
    p.price,
    p.selected_by_percent,
    p.form,
    p.total_points,
    p.points_per_game,
    p.points_per_million,
    p.points_per_90,
    p.expected_goals,
    p.expected_assists,
    p.expected_goal_involvements,
    p.minutes,
    p.starts,
    p.status,
    p.news,

    -- Higher = high returns relative to how few people own them
    round(
        safe_divide(p.total_points, nullif(p.selected_by_percent, 0)),
        2
    )                                                                   as differential_score

from players p
left join teams t on p.team = t.team_id

where p.selected_by_percent < 15
  and p.minutes > 450
  and p.status = 'a'

order by differential_score desc
