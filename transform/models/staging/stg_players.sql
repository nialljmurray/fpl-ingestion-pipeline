with source as (
    select * from {{ source('fpl_data', 'players') }}
),

renamed as (
    select
        id                                                              as player_id,
        first_name,
        second_name,
        web_name,
        team,
        element_type                                                    as position_id,
        case element_type
            when 1 then 'Goalkeeper'
            when 2 then 'Defender'
            when 3 then 'Midfielder'
            when 4 then 'Forward'
        end                                                             as position,
        status,
        news,

        -- Cost
        round(now_cost / 10.0, 1)                                      as price,
        cost_change_start,
        cost_change_event,

        -- Season totals
        minutes,
        total_points,
        starts,
        goals_scored,
        assists,
        clean_sheets,
        goals_conceded,
        own_goals,
        yellow_cards,
        red_cards,
        saves,
        bonus,
        bps,
        penalties_saved,
        penalties_missed,

        -- xG metrics (cast from string)
        cast(expected_goals as float64)                                 as expected_goals,
        cast(expected_assists as float64)                               as expected_assists,
        cast(expected_goal_involvements as float64)                     as expected_goal_involvements,
        cast(expected_goals_conceded as float64)                        as expected_goals_conceded,

        -- Per 90 metrics (already float)
        expected_goals_per_90,
        expected_assists_per_90,
        expected_goal_involvements_per_90,
        expected_goals_conceded_per_90,
        saves_per_90,
        goals_conceded_per_90,
        starts_per_90,
        clean_sheets_per_90,
        defensive_contribution_per_90,

        -- ICT metrics (cast from string)
        cast(influence as float64)                                      as influence,
        cast(creativity as float64)                                     as creativity,
        cast(threat as float64)                                         as threat,
        cast(ict_index as float64)                                      as ict_index,

        -- Form and selection (cast from string)
        cast(form as float64)                                           as form,
        cast(selected_by_percent as float64)                            as selected_by_percent,
        cast(points_per_game as float64)                                as points_per_game,

        -- Transfer activity
        transfers_in,
        transfers_out,
        transfers_in_event,
        transfers_out_event,

        -- Computed value metrics
        round(safe_divide(total_points, now_cost / 10.0), 2)           as points_per_million,
        round(safe_divide(total_points, nullif(minutes, 0)) * 90, 2)   as points_per_90

    from source
)

select * from renamed
