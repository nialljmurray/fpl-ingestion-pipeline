with player_gameweek as (
    select * from {{ ref('fct_player_gameweek') }}
)

select
    player_id,
    web_name,
    first_name,
    second_name,
    position,
    team_name,
    team_short_name,

    -- Appearances
    count(*)                                                            as gameweeks_played,
    sum(case when minutes > 0 then 1 else 0 end)                      as gameweeks_with_minutes,
    sum(starts)                                                         as starts,
    sum(minutes)                                                        as total_minutes,

    -- Goal contributions
    sum(total_points)                                                   as total_points,
    sum(goals_scored)                                                   as goals_scored,
    sum(assists)                                                        as assists,
    sum(goals_scored) + sum(assists)                                   as goal_involvements,
    sum(clean_sheets)                                                   as clean_sheets,
    sum(goals_conceded)                                                 as goals_conceded,
    sum(own_goals)                                                      as own_goals,

    -- Discipline
    sum(yellow_cards)                                                   as yellow_cards,
    sum(red_cards)                                                      as red_cards,

    -- Bonus and saves
    sum(bonus)                                                          as total_bonus,
    sum(bps)                                                            as total_bps,
    sum(saves)                                                          as saves,
    sum(penalties_saved)                                                as penalties_saved,
    sum(penalties_missed)                                               as penalties_missed,

    -- Defensive
    sum(clearances_blocks_interceptions)                               as clearances_blocks_interceptions,
    sum(recoveries)                                                     as recoveries,
    sum(tackles)                                                        as tackles,

    -- xG totals
    round(sum(expected_goals), 2)                                      as expected_goals,
    round(sum(expected_assists), 2)                                    as expected_assists,
    round(sum(expected_goal_involvements), 2)                          as expected_goal_involvements,
    round(sum(expected_goals_conceded), 2)                             as expected_goals_conceded,

    -- Per 90 rates
    round(safe_divide(sum(expected_goals), sum(minutes)) * 90, 2)     as xg_per_90,
    round(safe_divide(sum(expected_assists), sum(minutes)) * 90, 2)   as xa_per_90,
    round(safe_divide(sum(expected_goal_involvements), sum(minutes)) * 90, 2) as xgi_per_90,
    round(safe_divide(sum(total_points), sum(minutes)) * 90, 2)       as points_per_90,
    round(safe_divide(sum(goals_scored), sum(minutes)) * 90, 2)       as goals_per_90,
    round(safe_divide(sum(assists), sum(minutes)) * 90, 2)            as assists_per_90,

    -- Price
    round(avg(price), 1)                                               as avg_price,
    max(price)                                                         as current_price,
    round(safe_divide(sum(total_points), max(price)), 2)              as points_per_million

from player_gameweek
group by 1, 2, 3, 4, 5, 6, 7
order by total_points desc
