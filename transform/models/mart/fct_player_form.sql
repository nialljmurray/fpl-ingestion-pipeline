with player_gameweek as (
    select * from {{ ref('fct_player_gameweek') }}
),

rolling as (
    select
        gameweek,
        player_id,
        web_name,
        position,
        team_name,
        price,
        total_points,

        -- Rolling 5 GW windows
        sum(total_points) over (
            partition by player_id
            order by gameweek
            rows between 4 preceding and current row
        )                                                               as points_last_5_gw,

        avg(total_points) over (
            partition by player_id
            order by gameweek
            rows between 4 preceding and current row
        )                                                               as avg_points_last_5_gw,

        sum(expected_goal_involvements) over (
            partition by player_id
            order by gameweek
            rows between 4 preceding and current row
        )                                                               as xgi_last_5_gw,

        sum(minutes) over (
            partition by player_id
            order by gameweek
            rows between 4 preceding and current row
        )                                                               as minutes_last_5_gw,

        count(*) over (
            partition by player_id
            order by gameweek
            rows between 4 preceding and current row
        )                                                               as gw_count_in_window,

        ict_index,
        avg(ict_index) over (
            partition by player_id
            order by gameweek
            rows between 4 preceding and current row
        )                                                               as avg_ict_last_5_gw,

        row_number() over (partition by player_id order by gameweek desc) as rn

    from player_gameweek
)

select
    gameweek                                                            as latest_gameweek,
    player_id,
    web_name,
    position,
    team_name,
    price,
    total_points                                                        as last_gw_points,
    points_last_5_gw,
    round(avg_points_last_5_gw, 2)                                     as avg_points_last_5_gw,
    round(xgi_last_5_gw, 2)                                            as xgi_last_5_gw,
    minutes_last_5_gw,
    gw_count_in_window,
    round(ict_index, 2)                                                 as last_gw_ict,
    round(avg_ict_last_5_gw, 2)                                        as avg_ict_last_5_gw

from rolling
where rn = 1
order by points_last_5_gw desc
